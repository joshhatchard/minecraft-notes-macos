import BookCore
import Foundation
import Testing

@testable import BookStorage

@Suite("File-system repository")
struct FileSystemRepositoryTests {
    let folder: TemporaryFolder
    let repository: FileSystemLibraryRepository

    init() throws {
        folder = try TemporaryFolder()
        repository = FileSystemLibraryRepository(rootURL: folder.url, deletionMode: .removePermanently, now: { fixedDate })
    }

    private func makeBook(_ title: String = "Week 1") throws -> BookID {
        let chest = try repository.createChest(named: "Semester 1")
        let shelf = try repository.createShelf(named: "Physics", in: chest)
        return try repository.createBook(titled: title, in: shelf, slot: nil)
    }

    @Test func writesTheDocumentedFolderLayout() throws {
        let id = try makeBook()
        #expect(folder.exists("library.json"))
        #expect(folder.exists("Semester 1/chest.json"))
        #expect(folder.exists("Semester 1/Physics/Week 1.book/book.json"))
        #expect(folder.exists("Semester 1/Physics/Week 1.book/pages/001.md"))

        let json =
            try JSONSerialization.jsonObject(with: Data(folder.read("Semester 1/Physics/Week 1.book/book.json").utf8)) as? [String: Any]
        #expect(json?["title"] as? String == "Week 1")
        #expect(json?["signed"] as? Bool == false)
        #expect(json?["slot"] as? Int == 0)
        #expect(json?["createdAt"] as? String == "2023-11-14T22:13:20Z")
        _ = id
    }

    @Test func savesOnePlainTextFilePerPageAndRemovesStalePages() throws {
        let id = try makeBook()
        var book = try repository.loadBook(id)
        let fitter = PageFitter()
        try book.setText("first", onPage: 0, fitter: fitter, now: fixedDate)
        try book.appendPage(now: fixedDate)
        try book.setText("second", onPage: 1, fitter: fitter, now: fixedDate)
        try repository.saveBook(book, as: id)
        #expect(try folder.contents(of: "Semester 1/Physics/Week 1.book/pages") == ["001.md", "002.md"])
        #expect(try folder.read("Semester 1/Physics/Week 1.book/pages/002.md") == "second")

        let shorter = Book(title: book.title, createdAt: book.createdAt, pages: [Page(text: "only")])
        try repository.saveBook(shorter, as: id)
        #expect(try folder.contents(of: "Semester 1/Physics/Week 1.book/pages") == ["001.md"])
    }

    @Test func atomicWritesLeaveNoTemporaryFiles() throws {
        let id = try makeBook()
        var book = try repository.loadBook(id)
        for index in 0..<5 {
            try book.setText("revision \(index)", onPage: 0, fitter: PageFitter(), now: fixedDate)
            try repository.saveBook(book, as: id)
        }
        let files = try FileManager.default.contentsOfDirectory(
            atPath: folder.url.appending(path: "Semester 1/Physics/Week 1.book/pages").path(percentEncoded: false)
        )
        #expect(files == ["001.md"])
        #expect(try folder.read("Semester 1/Physics/Week 1.book/pages/001.md") == "revision 4")
    }

    @Test func atomicWriterReplacesExistingFiles() throws {
        let target = folder.url.appending(path: "file.txt")
        try AtomicFileWriter.write(Data("old".utf8), to: target)
        try AtomicFileWriter.write(Data("new".utf8), to: target)
        #expect(try folder.read("file.txt") == "new")
        #expect(try folder.contents(of: "") == ["file.txt"])
    }

    @Test func atomicWriterFailsCleanlyIntoAMissingFolder() {
        let target = folder.url.appending(path: "missing/file.txt")
        #expect(throws: LibraryError.self) { try AtomicFileWriter.write(Data("x".utf8), to: target) }
    }

    @Test func corruptedBookJSONFallsBackAndIsBackedUpOnSave() throws {
        let id = try makeBook()
        try folder.write("first page survives", to: "Semester 1/Physics/Week 1.book/pages/001.md")
        try folder.write("{ not json", to: "Semester 1/Physics/Week 1.book/book.json")

        let summary = try repository.shelves(in: id.shelf.chest)[0].books[0]
        #expect(summary.title == "Week 1")
        let book = try repository.loadBook(id)
        #expect(book.title == "Week 1")
        #expect(book.pages[0].text == "first page survives")

        try repository.saveBook(book, as: id)
        let entries = try folder.contents(of: "Semester 1/Physics/Week 1.book")
        #expect(entries.contains("book.json"))
        let backup = try #require(entries.first { $0.hasPrefix("book.json.corrupt-") })
        #expect(try folder.read("Semester 1/Physics/Week 1.book/\(backup)") == "{ not json")
        #expect(try repository.loadBook(id).title == "Week 1")
    }

    @Test func corruptedOrderFilesAreIgnored() throws {
        _ = try repository.createChest(named: "B")
        _ = try repository.createChest(named: "A")
        try folder.write("garbage", to: "library.json")
        #expect(try repository.chests().map(\.name) == ["A", "B"])
    }

    @Test func foldersAddedOutsideTheAppAppearAfterOrderedOnes() throws {
        _ = try repository.createChest(named: "Zeta")
        try FileManager.default.createDirectory(at: folder.url.appending(path: "Alpha"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.url.appending(path: ".hidden"), withIntermediateDirectories: true)
        #expect(try repository.chests().map(\.name) == ["Zeta", "Alpha"])
    }

    @Test func duplicateOrMissingSlotsAreRepairedWhenListing() throws {
        let first = try makeBook("A")
        let second = try repository.createBook(titled: "B", in: first.shelf, slot: nil)
        let third = try repository.createBook(titled: "C", in: first.shelf, slot: nil)
        let base = "Semester 1/Physics"
        try folder.write(
            #"{"version":1,"title":"B","author":"","signed":false,"createdAt":"2023-11-14T22:13:20Z","updatedAt":"2023-11-14T22:13:20Z","slot":0}"#,
            to: "\(base)/B.book/book.json")
        try folder.write(
            #"{"version":1,"title":"C","author":"","signed":false,"createdAt":"2023-11-14T22:13:20Z","updatedAt":"2023-11-14T22:13:20Z"}"#,
            to: "\(base)/C.book/book.json")
        let books = try repository.shelves(in: first.shelf.chest)[0].books
        #expect(Set(books.map(\.slot)).count == 3)
        #expect(books.first { $0.id == first }?.slot == 0)
        #expect(books.first { $0.id == second }?.slot == 1)
        #expect(books.first { $0.id == third }?.slot == 2)
    }

    @Test func pagesWithGapsLoadInOrder() throws {
        let id = try makeBook()
        try folder.write("one", to: "Semester 1/Physics/Week 1.book/pages/001.md")
        try folder.write("three", to: "Semester 1/Physics/Week 1.book/pages/003.md")
        try folder.write("ignored", to: "Semester 1/Physics/Week 1.book/pages/notes.txt")
        #expect(try repository.loadBook(id).pages.map(\.text) == ["one", "three"])
    }

    @Test func chestNamedLikeTheIndexFileDoesNotCollide() throws {
        _ = try repository.createChest(named: "First")
        let chest = try repository.createChest(named: "library.json")
        #expect(chest.name == "library.json 2")
    }

    @Test func deletingMovesNothingElse() throws {
        let id = try makeBook()
        _ = try repository.createBook(titled: "Keep", in: id.shelf, slot: nil)
        try repository.deleteBook(id)
        #expect(try folder.contents(of: "Semester 1/Physics") == ["Keep.book"])
    }

    @Test func sanitiserHandlesEdgeCases() {
        #expect(FileNaming.sanitize("  ") == "Untitled")
        #expect(FileNaming.sanitize("...") == "Untitled")
        #expect(FileNaming.sanitize("name. ") == "name")
        #expect(FileNaming.sanitize("a\u{0007}b") == "a-b")
        #expect(FileNaming.sanitize(String(repeating: "x", count: 200)).count == FileNaming.maxLength)
        #expect(FileNaming.unique("A", among: ["a", "A 2"]) == "A 3")
    }
}
