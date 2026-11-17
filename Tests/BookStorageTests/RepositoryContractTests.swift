import BookCore
import BookStorage
import Testing

/// Behaviour every ``LibraryRepository`` must share, run against both the
/// file-system implementation and the in-memory fake.
@Suite("Repository contract")
struct RepositoryContractTests {
    @Test(arguments: RepositoryKind.allCases)
    func createsAndListsChestsInCreationOrder(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        _ = try repository.createChest(named: "Semester 2")
        _ = try repository.createChest(named: "Semester 1")
        #expect(try repository.chests().map(\.name) == ["Semester 2", "Semester 1"])
    }

    @Test(arguments: RepositoryKind.allCases)
    func nameCollisionsGetASuffix(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let first = try repository.createChest(named: "Maths")
        let second = try repository.createChest(named: "maths")
        #expect(first.name == "Maths")
        #expect(second.name == "maths 2")
        let shelf = try repository.createShelf(named: "Algebra", in: first)
        let again = try repository.createShelf(named: "Algebra", in: first)
        #expect(again.name == "Algebra 2")
        let book = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)
        let twin = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)
        #expect(book.folderName == "Week 1")
        #expect(twin.folderName == "Week 1 2")
    }

    @Test(arguments: RepositoryKind.allCases)
    func illegalCharactersAreReplaced(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "S1/2026: Core?")
        #expect(chest.name == "S1-2026- Core-")
        let hidden = try repository.createChest(named: "..secret")
        #expect(hidden.name == "secret")
        let shelf = try repository.createShelf(named: "Physics", in: chest)
        let book = try repository.createBook(titled: "A/B", in: shelf, slot: nil)
        #expect(book.folderName == "A-B")
        #expect(try repository.loadBook(book).title == "A/B")
    }

    @Test(arguments: RepositoryKind.allCases)
    func invalidNamesAreRejected(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        #expect(throws: LibraryError.invalidName(.empty)) { try repository.createChest(named: "   ") }
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        #expect(throws: LibraryError.invalidName(.tooLong(max: BookLimits.maxTitleLength))) {
            try repository.createBook(titled: String(repeating: "x", count: 40), in: shelf, slot: nil)
        }
    }

    @Test(arguments: RepositoryKind.allCases)
    func renamesKeepContentAndOrder(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let first = try repository.createChest(named: "A")
        _ = try repository.createChest(named: "B")
        let shelf = try repository.createShelf(named: "Physics", in: first)
        let book = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)

        let renamedChest = try repository.renameChest(first, to: "Z")
        #expect(try repository.chests().map(\.name) == ["Z", "B"])
        let movedShelf = ShelfID(chest: renamedChest, name: "Physics")
        let renamedShelf = try repository.renameShelf(movedShelf, to: "Physics 101")
        let movedBook = BookID(shelf: renamedShelf, folderName: book.folderName)
        let renamedBook = try repository.renameBook(movedBook, to: "Kinematics")

        #expect(renamedBook.folderName == "Kinematics")
        #expect(try repository.loadBook(renamedBook).title == "Kinematics")
        #expect(throws: LibraryError.self) { try repository.loadBook(movedBook) }
    }

    @Test(arguments: RepositoryKind.allCases)
    func caseOnlyRenameWorks(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "maths")
        let renamed = try repository.renameChest(chest, to: "Maths")
        #expect(renamed.name == "Maths")
        #expect(try repository.chests().map(\.name) == ["Maths"])
    }

    @Test(arguments: RepositoryKind.allCases)
    func deletesRemoveItems(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let book = try repository.createBook(titled: "B", in: shelf, slot: nil)
        try repository.deleteBook(book)
        #expect(try repository.shelves(in: chest)[0].books.isEmpty)
        try repository.deleteShelf(shelf)
        #expect(try repository.shelves(in: chest).isEmpty)
        try repository.deleteChest(chest)
        #expect(try repository.chests().isEmpty)
    }

    @Test(arguments: RepositoryKind.allCases)
    func booksFillFreeSlotsAndHonourRequestedSlots(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let a = try repository.createBook(titled: "A", in: shelf, slot: nil)
        let b = try repository.createBook(titled: "B", in: shelf, slot: 4)
        let c = try repository.createBook(titled: "C", in: shelf, slot: 4)
        let books = try repository.shelves(in: chest)[0].books
        #expect(books.first { $0.id == a }?.slot == 0)
        #expect(books.first { $0.id == b }?.slot == 4)
        #expect(books.first { $0.id == c }?.slot == 1)
        #expect(throws: LibraryError.invalidSlot(-1)) { try repository.createBook(titled: "D", in: shelf, slot: -1) }
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingABookToAnEmptySlotOnAnotherShelf(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let physics = try repository.createShelf(named: "Physics", in: chest)
        let maths = try repository.createShelf(named: "Maths", in: chest)
        let book = try repository.createBook(titled: "Notes", in: physics, slot: nil)
        var saved = try repository.loadBook(book)
        try saved.setText("F = ma", onPage: 0, fitter: PageFitter(), now: fixedDate)
        try repository.saveBook(saved, as: book)

        let move = try repository.moveBook(book, to: maths, slot: 3)
        #expect(move.moved == BookID(shelf: maths, folderName: "Notes"))
        #expect(move.displaced == nil)
        let shelves = try repository.shelves(in: chest)
        #expect(shelves.first { $0.id == physics }?.books.isEmpty == true)
        #expect(shelves.first { $0.id == maths }?.books.map(\.slot) == [3])
        #expect(try repository.loadBook(move.moved).pages[0].text == "F = ma")
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingOntoAnOccupiedSlotSwaps(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let left = try repository.createShelf(named: "Left", in: chest)
        let right = try repository.createShelf(named: "Right", in: chest)
        let a = try repository.createBook(titled: "A", in: left, slot: 2)
        let b = try repository.createBook(titled: "B", in: right, slot: 5)

        let move = try repository.moveBook(a, to: right, slot: 5)
        #expect(move.moved == BookID(shelf: right, folderName: "A"))
        #expect(move.displaced == BookID(shelf: left, folderName: b.folderName))
        let shelves = try repository.shelves(in: chest)
        #expect(shelves.first { $0.id == left }?.books.map(\.title) == ["B"])
        #expect(shelves.first { $0.id == left }?.books.map(\.slot) == [2])
        #expect(shelves.first { $0.id == right }?.books.map(\.title) == ["A"])
        #expect(shelves.first { $0.id == right }?.books.map(\.slot) == [5])
    }

    @Test(arguments: RepositoryKind.allCases)
    func swappingWithinAShelf(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let a = try repository.createBook(titled: "A", in: shelf, slot: 0)
        let b = try repository.createBook(titled: "B", in: shelf, slot: 1)
        let move = try repository.moveBook(a, to: shelf, slot: 1)
        #expect(move.moved == a)
        #expect(move.displaced == b)
        let books = try repository.shelves(in: chest)[0].books
        #expect(books.map(\.title) == ["B", "A"])
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingABookIntoACollidingName(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let left = try repository.createShelf(named: "Left", in: chest)
        let right = try repository.createShelf(named: "Right", in: chest)
        let leftBook = try repository.createBook(titled: "Week 1", in: left, slot: nil)
        _ = try repository.createBook(titled: "Week 1", in: right, slot: 0)
        let move = try repository.moveBook(leftBook, to: right, slot: 1)
        #expect(move.moved.folderName == "Week 1 2")
        #expect(try repository.shelves(in: chest).first { $0.id == right }?.books.count == 2)
    }

    @Test(arguments: RepositoryKind.allCases)
    func movingAShelfToAnotherChest(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let first = try repository.createChest(named: "S1")
        let second = try repository.createChest(named: "S2")
        let shelf = try repository.createShelf(named: "Physics", in: first)
        _ = try repository.createShelf(named: "Physics", in: second)
        let book = try repository.createBook(titled: "Notes", in: shelf, slot: nil)

        let moved = try repository.moveShelf(shelf, to: second)
        #expect(moved == ShelfID(chest: second, name: "Physics 2"))
        #expect(try repository.shelves(in: first).isEmpty)
        #expect(try repository.shelves(in: second).map(\.name) == ["Physics", "Physics 2"])
        #expect(try repository.loadBook(BookID(shelf: moved, folderName: book.folderName)).title == "Notes")
        #expect(try repository.chests().map(\.shelfCount) == [0, 2])
    }

    @Test(arguments: RepositoryKind.allCases)
    func savingAndLoadingRoundTrips(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let chest = try repository.createChest(named: "C")
        let shelf = try repository.createShelf(named: "S", in: chest)
        let id = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)
        var book = try repository.loadBook(id)
        let fitter = PageFitter()
        try book.setText("Page one ✏️\nline two", onPage: 0, fitter: fitter, now: fixedDate)
        try book.appendPage(now: fixedDate)
        try book.setText("Page two", onPage: 1, fitter: fitter, now: fixedDate)
        try book.sign(title: "Week 1", author: "Josh", now: fixedDate)
        try repository.saveBook(book, as: id)

        let loaded = try repository.loadBook(id)
        #expect(loaded == book)
        let summary = try repository.shelves(in: chest)[0].books[0]
        #expect(summary.isSigned)
        #expect(summary.author == "Josh")
    }

    @Test(arguments: RepositoryKind.allCases)
    func missingItemsReportNotFound(kind: RepositoryKind) throws {
        let (repository, keepAlive) = try kind.make()
        _ = keepAlive
        let ghost = ChestID(name: "Ghost")
        #expect(throws: LibraryError.self) { try repository.shelves(in: ghost) }
        #expect(throws: LibraryError.self) { try repository.renameChest(ghost, to: "X") }
        #expect(throws: LibraryError.self) {
            try repository.loadBook(BookID(shelf: ShelfID(chest: ghost, name: "S"), folderName: "B"))
        }
    }
}
