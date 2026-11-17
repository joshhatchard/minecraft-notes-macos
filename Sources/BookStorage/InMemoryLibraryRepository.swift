import BookCore
import Foundation
import Synchronization

/// A ``LibraryRepository`` kept entirely in memory, for tests and previews.
///
/// It follows the same naming, collision, slot and swap rules as
/// ``FileSystemLibraryRepository`` without touching the disk.
public final class InMemoryLibraryRepository: LibraryRepository {
    private struct StoredBook {
        var folder: String
        var book: Book
        var slot: Int
    }

    private struct StoredShelf {
        var name: String
        var books: [StoredBook] = []
    }

    private struct StoredChest {
        var name: String
        var shelves: [StoredShelf] = []
    }

    private let state = Mutex<[StoredChest]>([])
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    // MARK: Chests

    public func chests() throws(LibraryError) -> [ChestSummary] {
        state.withLock { chests in
            chests.map { ChestSummary(id: ChestID(name: $0.name), shelfCount: $0.shelves.count) }
        }
    }

    public func createChest(named name: String) throws(LibraryError) -> ChestID {
        let base = try FileNaming.containerFolderName(for: name)
        return state.withLock { chests in
            let folder = FileNaming.unique(base, among: chests.map(\.name))
            chests.append(StoredChest(name: folder))
            return ChestID(name: folder)
        }
    }

    public func renameChest(_ chest: ChestID, to name: String) throws(LibraryError) -> ChestID {
        let base = try FileNaming.containerFolderName(for: name)
        return try mutate { chests throws(LibraryError) in
            let index = try Self.chestIndex(chest, in: chests)
            let folder = FileNaming.unique(base, among: chests.map(\.name).filter { $0 != chest.name })
            chests[index].name = folder
            return ChestID(name: folder)
        }
    }

    public func deleteChest(_ chest: ChestID) throws(LibraryError) {
        try mutate { chests throws(LibraryError) in
            chests.remove(at: try Self.chestIndex(chest, in: chests))
        }
    }

    // MARK: Shelves

    public func shelves(in chest: ChestID) throws(LibraryError) -> [ShelfSummary] {
        try mutate { chests throws(LibraryError) in
            let stored = chests[try Self.chestIndex(chest, in: chests)]
            return stored.shelves.map { shelf in
                let id = ShelfID(chest: chest, name: shelf.name)
                return ShelfSummary(id: id, books: shelf.books.map { Self.summary(of: $0, on: id) })
            }
        }
    }

    public func createShelf(named name: String, in chest: ChestID) throws(LibraryError) -> ShelfID {
        let base = try FileNaming.containerFolderName(for: name)
        return try mutate { chests throws(LibraryError) in
            let index = try Self.chestIndex(chest, in: chests)
            let folder = FileNaming.unique(base, among: chests[index].shelves.map(\.name))
            chests[index].shelves.append(StoredShelf(name: folder))
            return ShelfID(chest: chest, name: folder)
        }
    }

    public func renameShelf(_ shelf: ShelfID, to name: String) throws(LibraryError) -> ShelfID {
        let base = try FileNaming.containerFolderName(for: name)
        return try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex) = try Self.shelfIndex(shelf, in: chests)
            let others = chests[chestIndex].shelves.map(\.name).filter { $0 != shelf.name }
            let folder = FileNaming.unique(base, among: others)
            chests[chestIndex].shelves[shelfIndex].name = folder
            return ShelfID(chest: shelf.chest, name: folder)
        }
    }

    public func deleteShelf(_ shelf: ShelfID) throws(LibraryError) {
        try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex) = try Self.shelfIndex(shelf, in: chests)
            chests[chestIndex].shelves.remove(at: shelfIndex)
        }
    }

    public func moveShelf(_ shelf: ShelfID, to chest: ChestID) throws(LibraryError) -> ShelfID {
        try mutate { chests throws(LibraryError) in
            let (sourceChest, shelfIndex) = try Self.shelfIndex(shelf, in: chests)
            let targetChest = try Self.chestIndex(chest, in: chests)
            guard sourceChest != targetChest else { return shelf }
            var moving = chests[sourceChest].shelves.remove(at: shelfIndex)
            moving.name = FileNaming.unique(moving.name, among: chests[targetChest].shelves.map(\.name))
            chests[targetChest].shelves.append(moving)
            return ShelfID(chest: chest, name: moving.name)
        }
    }

    // MARK: Books

    public func createBook(titled title: String, in shelf: ShelfID, slot: Int?) throws(LibraryError) -> BookID {
        let validTitle = try FileNaming.validTitle(title)
        if let slot, slot < 0 { throw .invalidSlot(slot) }
        let created = now()
        return try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex) = try Self.shelfIndex(shelf, in: chests)
            let books = chests[chestIndex].shelves[shelfIndex].books
            let occupied = Set(books.map(\.slot))
            let target = slot.flatMap { occupied.contains($0) ? nil : $0 } ?? ShelfLayout.firstFreeSlot(occupied: occupied)
            let folder = FileNaming.unique(FileNaming.sanitize(validTitle), among: books.map(\.folder))
            let book = Book(title: validTitle, createdAt: created)
            chests[chestIndex].shelves[shelfIndex].books.append(StoredBook(folder: folder, book: book, slot: target))
            return BookID(shelf: shelf, folderName: folder)
        }
    }

    public func renameBook(_ book: BookID, to title: String) throws(LibraryError) -> BookID {
        let validTitle = try FileNaming.validTitle(title)
        let changed = now()
        return try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex, bookIndex) = try Self.bookIndex(book, in: chests)
            let others = chests[chestIndex].shelves[shelfIndex].books.map(\.folder).filter { $0 != book.folderName }
            let folder = FileNaming.unique(FileNaming.sanitize(validTitle), among: others)
            var stored = chests[chestIndex].shelves[shelfIndex].books[bookIndex]
            do {
                try stored.book.rename(to: validTitle, now: changed)
            } catch {
                throw .io("Could not rename the book.")
            }
            stored.folder = folder
            chests[chestIndex].shelves[shelfIndex].books[bookIndex] = stored
            return BookID(shelf: book.shelf, folderName: folder)
        }
    }

    public func deleteBook(_ book: BookID) throws(LibraryError) {
        try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex, bookIndex) = try Self.bookIndex(book, in: chests)
            chests[chestIndex].shelves[shelfIndex].books.remove(at: bookIndex)
        }
    }

    public func moveBook(_ book: BookID, to shelf: ShelfID, slot: Int) throws(LibraryError) -> BookMove {
        guard slot >= 0 else { throw .invalidSlot(slot) }
        return try mutate { chests throws(LibraryError) in
            let (sourceChest, sourceShelf, bookIndex) = try Self.bookIndex(book, in: chests)
            let (targetChest, targetShelf) = try Self.shelfIndex(shelf, in: chests)
            var moving = chests[sourceChest].shelves[sourceShelf].books.remove(at: bookIndex)
            let sourceSlot = moving.slot
            let sameShelf = book.shelf == shelf
            if !sameShelf {
                moving.folder = FileNaming.unique(moving.folder, among: chests[targetChest].shelves[targetShelf].books.map(\.folder))
            }
            var displacedID: BookID?
            if let occupantIndex = chests[targetChest].shelves[targetShelf].books.firstIndex(where: { $0.slot == slot }) {
                var occupant = chests[targetChest].shelves[targetShelf].books.remove(at: occupantIndex)
                occupant.slot = sourceSlot
                if !sameShelf {
                    occupant.folder = FileNaming.unique(
                        occupant.folder, among: chests[sourceChest].shelves[sourceShelf].books.map(\.folder))
                }
                chests[sourceChest].shelves[sourceShelf].books.append(occupant)
                displacedID = BookID(shelf: book.shelf, folderName: occupant.folder)
            }
            moving.slot = slot
            chests[targetChest].shelves[targetShelf].books.append(moving)
            return BookMove(moved: BookID(shelf: shelf, folderName: moving.folder), displaced: displacedID)
        }
    }

    public func loadBook(_ book: BookID) throws(LibraryError) -> Book {
        try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex, bookIndex) = try Self.bookIndex(book, in: chests)
            return chests[chestIndex].shelves[shelfIndex].books[bookIndex].book
        }
    }

    public func saveBook(_ book: Book, as id: BookID) throws(LibraryError) {
        try mutate { chests throws(LibraryError) in
            let (chestIndex, shelfIndex, bookIndex) = try Self.bookIndex(id, in: chests)
            chests[chestIndex].shelves[shelfIndex].books[bookIndex].book = book
        }
    }

    // MARK: Helpers

    private func mutate<T>(_ body: (inout [StoredChest]) throws(LibraryError) -> T) throws(LibraryError) -> T {
        let result: Result<T, LibraryError> = state.withLock { chests in
            do throws(LibraryError) {
                return .success(try body(&chests))
            } catch {
                return .failure(error)
            }
        }
        return try result.get()
    }

    private static func summary(of stored: StoredBook, on shelf: ShelfID) -> BookSummary {
        BookSummary(
            id: BookID(shelf: shelf, folderName: stored.folder),
            title: stored.book.title,
            author: stored.book.author,
            isSigned: stored.book.isSigned,
            slot: stored.slot
        )
    }

    private static func chestIndex(_ chest: ChestID, in chests: [StoredChest]) throws(LibraryError) -> Int {
        guard let index = chests.firstIndex(where: { $0.name == chest.name }) else {
            throw .notFound("The chest “\(chest.name)”")
        }
        return index
    }

    private static func shelfIndex(_ shelf: ShelfID, in chests: [StoredChest]) throws(LibraryError) -> (Int, Int) {
        let chest = try chestIndex(shelf.chest, in: chests)
        guard let index = chests[chest].shelves.firstIndex(where: { $0.name == shelf.name }) else {
            throw .notFound("The shelf “\(shelf.name)”")
        }
        return (chest, index)
    }

    private static func bookIndex(_ book: BookID, in chests: [StoredChest]) throws(LibraryError) -> (Int, Int, Int) {
        let (chest, shelf) = try shelfIndex(book.shelf, in: chests)
        guard let index = chests[chest].shelves[shelf].books.firstIndex(where: { $0.folder == book.folderName }) else {
            throw .notFound("The book “\(book.folderName)”")
        }
        return (chest, shelf, index)
    }
}
