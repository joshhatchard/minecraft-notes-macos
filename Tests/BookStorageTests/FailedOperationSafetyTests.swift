import BookCore
import BookStorage
import Testing

/// A failed rename, move or delete must never lose or damage anything.
/// Runs against both the file-system implementation and the in-memory fake.
@Suite("Failed operations keep data safe")
struct FailedOperationSafetyTests {
    @Test(arguments: RepositoryKind.allCases)
    func movingABookToAMissingShelfKeepsIt(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let book = try repository.createBook(titled: "Notes", in: shelf, slot: 2)
        let ghost = ShelfID(chest: chest, name: "Ghost")

        #expect(throws: LibraryError.self) { try repository.moveBook(book, to: ghost, slot: 0) }
        #expect(throws: LibraryError.invalidSlot(-1)) { try repository.moveBook(book, to: shelf, slot: -1) }

        let books = try repository.shelves(in: chest)[0].books
        #expect(books.map(\.id) == [book])
        #expect(books.map(\.slot) == [2])
        #expect(try repository.loadBook(book).title == "Notes")
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingAShelfToAMissingChestKeepsItAndItsBooks(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let book = try repository.createBook(titled: "Notes", in: shelf, slot: nil)

        #expect(throws: LibraryError.self) { try repository.moveShelf(shelf, to: ChestID(name: "Ghost")) }

        #expect(try repository.shelves(in: chest).map(\.id) == [shelf])
        #expect(try repository.loadBook(book).title == "Notes")
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingAMissingBookChangesNothing(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let from = try repository.createShelf(named: "A", in: chest)
        let to = try repository.createShelf(named: "B", in: chest)
        let kept = try repository.createBook(titled: "Kept", in: to, slot: 0)

        #expect(throws: LibraryError.self) {
            try repository.moveBook(BookID(shelf: from, folderName: "Nope"), to: to, slot: 0)
        }
        #expect(try repository.shelves(in: chest)[1].books.map(\.id) == [kept])
    }

    @Test(arguments: RepositoryKind.allCases)
    func renamingToABlankNameKeepsTheOriginal(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let book = try repository.createBook(titled: "Notes", in: shelf, slot: nil)

        #expect(throws: LibraryError.invalidName(.empty)) { try repository.renameChest(chest, to: " ") }
        #expect(throws: LibraryError.invalidName(.empty)) { try repository.renameShelf(shelf, to: "") }
        #expect(throws: LibraryError.invalidName(.empty)) { try repository.renameBook(book, to: "  ") }

        #expect(try repository.chests().map(\.id) == [chest])
        #expect(try repository.shelves(in: chest).map(\.id) == [shelf])
        #expect(try repository.loadBook(book).title == "Notes")
    }

    @Test(arguments: RepositoryKind.allCases)
    func renamingOntoAnExistingNameNeverOverwrites(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let first = try repository.createBook(titled: "Alpha", in: shelf, slot: 0)
        let second = try repository.createBook(titled: "Beta", in: shelf, slot: 1)

        let renamed = try repository.renameBook(second, to: "Alpha")

        #expect(renamed != first)
        #expect(try repository.loadBook(first).title == "Alpha")
        #expect(try repository.loadBook(renamed).title == "Alpha")
        #expect(try repository.shelves(in: chest)[0].books.count == 2)
    }

    @Test(arguments: RepositoryKind.allCases)
    func movedShelfWithSameNameIsRenamedNotMerged(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let one = try repository.createChest(named: "One")
        let two = try repository.createChest(named: "Two")
        let mine = try repository.createShelf(named: "Physics", in: one)
        let theirs = try repository.createShelf(named: "Physics", in: two)
        _ = try repository.createBook(titled: "Mine", in: mine, slot: nil)
        let theirBook = try repository.createBook(titled: "Theirs", in: theirs, slot: nil)

        let moved = try repository.moveShelf(mine, to: two)

        #expect(moved != theirs)
        #expect(try repository.shelves(in: two).count == 2)
        #expect(try repository.loadBook(theirBook).title == "Theirs")
        #expect(try repository.shelves(in: two).first { $0.id == moved }?.books.map(\.title) == ["Mine"])
    }
}
