import BookAudio
import BookCore
import BookStorage
import Observation

/// An open chest: its shelves and books, plus drag-and-drop between them.
@MainActor
@Observable
public final class ChestViewModel: ErrorReporting {
    /// The chest being shown.
    public let chestID: ChestID
    /// Shelves in display order, each with its books.
    public private(set) var shelves: [ShelfSummary] = []
    /// Other chests, offered as drop targets for moving shelves.
    public private(set) var otherChests: [ChestSummary] = []
    public var errorMessage: String?

    @ObservationIgnored private let repository: any LibraryRepository
    @ObservationIgnored private let sound: any SoundPlaying

    public init(chestID: ChestID, repository: any LibraryRepository, sound: any SoundPlaying) {
        self.chestID = chestID
        self.repository = repository
        self.sound = sound
    }

    /// Re-reads shelves and the other chests from storage.
    public func reload() {
        if let loaded = attempt({ () throws(LibraryError) in try repository.shelves(in: chestID) }) {
            shelves = loaded
        }
        if let all = attempt({ () throws(LibraryError) in try repository.chests() }) {
            otherChests = all.filter { $0.id != chestID }
        }
    }

    /// Number of chiseled bookshelf blocks to draw for `shelf`.
    public func blockCount(for shelf: ShelfSummary) -> Int {
        ShelfLayout.blockCount(occupied: Set(shelf.books.map(\.slot)))
    }

    // MARK: Shelves

    /// Adds a shelf at the end of the chest.
    @discardableResult
    public func createShelf(named name: String) -> Bool {
        let created = attempt { () throws(LibraryError) in try repository.createShelf(named: name, in: chestID) }
        reload()
        return created != nil
    }

    /// Renames a shelf.
    @discardableResult
    public func renameShelf(_ shelf: ShelfID, to name: String) -> Bool {
        let renamed = attempt { () throws(LibraryError) in try repository.renameShelf(shelf, to: name) }
        reload()
        return renamed != nil
    }

    /// Deletes a shelf and its books.
    public func deleteShelf(_ shelf: ShelfID) {
        attempt { () throws(LibraryError) in try repository.deleteShelf(shelf) }
        reload()
    }

    /// Moves a shelf into another chest.
    @discardableResult
    public func moveShelf(_ shelf: ShelfID, to chest: ChestID) -> Bool {
        guard shelf.chest != chest else { return false }
        let moved = attempt { () throws(LibraryError) in try repository.moveShelf(shelf, to: chest) }
        reload()
        if moved != nil {
            sound.play(.bookPlace)
        }
        return moved != nil
    }

    // MARK: Books

    /// Creates a book on `shelf`, in `slot` if given and free.
    /// - Returns: The new book, or `nil` on failure.
    public func createBook(titled title: String, on shelf: ShelfID, slot: Int?) -> BookID? {
        let created = attempt { () throws(LibraryError) in try repository.createBook(titled: title, in: shelf, slot: slot) }
        reload()
        return created
    }

    /// Renames a book.
    @discardableResult
    public func renameBook(_ book: BookID, to title: String) -> Bool {
        let renamed = attempt { () throws(LibraryError) in try repository.renameBook(book, to: title) }
        reload()
        return renamed != nil
    }

    /// Deletes a book.
    public func deleteBook(_ book: BookID) {
        attempt { () throws(LibraryError) in try repository.deleteBook(book) }
        reload()
    }

    /// Moves a book to a slot; a book already there swaps into the old place.
    @discardableResult
    public func moveBook(_ book: BookID, to shelf: ShelfID, slot: Int) -> Bool {
        if book.shelf == shelf, shelves.first(where: { $0.id == shelf })?.books.first(where: { $0.id == book })?.slot == slot {
            return false
        }
        let moved = attempt { () throws(LibraryError) in try repository.moveBook(book, to: shelf, slot: slot) }
        reload()
        if moved != nil {
            sound.play(.bookPlace)
        }
        return moved != nil
    }

    // MARK: Drops

    /// Handles strings dropped on a shelf slot. Only book payloads are accepted.
    public func handleDrop(_ items: [String], onSlot slot: Int, of shelf: ShelfID) -> Bool {
        guard let payload = items.lazy.compactMap(DragPayload.init(encoded:)).first,
            case .book(let book) = payload
        else { return false }
        return moveBook(book, to: shelf, slot: slot)
    }

    /// Handles strings dropped on a chest. Only shelf payloads are accepted.
    public func handleDrop(_ items: [String], onChest chest: ChestID) -> Bool {
        guard let payload = items.lazy.compactMap(DragPayload.init(encoded:)).first,
            case .shelf(let shelf) = payload
        else { return false }
        return moveShelf(shelf, to: chest)
    }
}
