import BookAudio
import BookCore
import BookStorage
import Foundation
import Testing

@testable import BookUI

@MainActor
@Suite("Navigation and library view models")
struct LibraryViewModelTests {
    @Test func navigatesChestToBookAndBack() throws {
        let fixture = try Fixture()
        let app = fixture.makeApp()
        #expect(app.route == .chests)
        #expect(app.chestList.chests.map(\.name) == ["Semester 1"])

        app.openChest(fixture.chest)
        #expect(app.route == .chest(fixture.chest))
        #expect(app.chest?.shelves.map(\.name) == ["Physics"])

        app.openBook(fixture.book)
        #expect(app.route == .book(fixture.book))
        #expect(app.editor?.book.title == "Week 1")

        app.goBack()
        #expect(app.route == .chest(fixture.chest))
        #expect(app.editor == nil)
        app.goBack()
        #expect(app.route == .chests)
        #expect(app.chest == nil)
        #expect(fixture.sound.played == [.chestOpen, .bookOpen])
    }

    @Test func leavingTheBookSavesIt() throws {
        let fixture = try Fixture()
        let app = fixture.makeApp()
        app.openChest(fixture.chest)
        app.openBook(fixture.book)
        _ = app.editor?.applyEdit(replacing: NSRange(location: 0, length: 0), with: "Lecture notes")
        app.goBack()
        #expect(try fixture.repository.loadBook(fixture.book).pages[0].text == "Lecture notes")
    }

    @Test func flushPendingChangesSavesTheOpenBook() throws {
        let fixture = try Fixture()
        let app = fixture.makeApp()
        app.openBook(fixture.book)
        _ = app.editor?.applyEdit(replacing: NSRange(location: 0, length: 0), with: "Quit safely")
        #expect(app.flushPendingChanges())
        #expect(try fixture.repository.loadBook(fixture.book).pages[0].text == "Quit safely")
    }

    @Test func openingAMissingBookReportsAnError() throws {
        let fixture = try Fixture()
        let app = fixture.makeApp()
        app.openChest(fixture.chest)
        app.openBook(BookID(shelf: fixture.shelf, folderName: "Nope"))
        #expect(app.route == .chest(fixture.chest))
        #expect(app.chest?.errorMessage != nil)
    }

    @Test func changingTheLibraryRootReturnsHome() throws {
        let fixture = try Fixture()
        let app = fixture.makeApp()
        app.openChest(fixture.chest)
        let newRoot = URL(filePath: "/tmp/other-library")
        app.changeLibraryRoot(to: newRoot)
        #expect(app.route == .chests)
        #expect(app.libraryRoot == newRoot)
        #expect(fixture.preferences.libraryRootPath == "/tmp/other-library")
    }

    @Test func chestListCreatesRenamesAndDeletes() throws {
        let fixture = try Fixture()
        let model = ChestListViewModel(repository: fixture.repository)
        #expect(model.createChest(named: "Semester 2"))
        #expect(model.chests.map(\.name) == ["Semester 1", "Semester 2"])
        #expect(!model.createChest(named: "  "))
        #expect(model.takeErrorMessage() == "Please enter a name.")
        #expect(model.errorMessage == nil)
        #expect(model.renameChest(ChestID(name: "Semester 2"), to: "Summer"))
        model.deleteChest(ChestID(name: "Summer"))
        #expect(model.chests.map(\.name) == ["Semester 1"])
    }

    @Test func chestModelManagesShelvesAndBooks() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        model.reload()
        #expect(model.createShelf(named: "Maths"))
        #expect(model.shelves.map(\.name) == ["Physics", "Maths"])
        let maths = ShelfID(chest: fixture.chest, name: "Maths")
        let created = try #require(model.createBook(titled: "Vectors", on: maths, slot: 3))
        #expect(model.shelves[1].book(inSlot: 3)?.id == created)
        #expect(model.renameBook(created, to: "Matrices"))
        #expect(model.shelves[1].books.map(\.title) == ["Matrices"])
        #expect(model.renameShelf(maths, to: "Linear Algebra"))
        model.deleteShelf(ShelfID(chest: fixture.chest, name: "Linear Algebra"))
        #expect(model.shelves.map(\.name) == ["Physics"])
        model.deleteBook(fixture.book)
        #expect(model.shelves[0].books.isEmpty)
    }

    @Test func droppingABookOnASlotMovesIt() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        #expect(model.createShelf(named: "Maths"))
        let maths = ShelfID(chest: fixture.chest, name: "Maths")

        let payload = DragPayload.book(fixture.book).encoded
        #expect(model.handleDrop([payload], onSlot: 4, of: maths))
        #expect(model.shelves.first { $0.id == maths }?.books.map(\.slot) == [4])
        #expect(model.shelves.first { $0.id == fixture.shelf }?.books.isEmpty == true)
        #expect(fixture.sound.played == [.bookPlace])
    }

    @Test func droppingABookOnItsOwnSlotDoesNothing() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        model.reload()
        #expect(!model.handleDrop([DragPayload.book(fixture.book).encoded], onSlot: 0, of: fixture.shelf))
        #expect(fixture.sound.played.isEmpty)
    }

    @Test func droppingAShelfOnAChestMovesIt() throws {
        let fixture = try Fixture()
        let other = try fixture.repository.createChest(named: "Semester 2")
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        model.reload()
        #expect(model.otherChests.map(\.id) == [other])
        #expect(model.handleDrop([DragPayload.shelf(fixture.shelf).encoded], onChest: other))
        #expect(model.shelves.isEmpty)
        #expect(try fixture.repository.shelves(in: other).map(\.name) == ["Physics"])
    }

    @Test func aFailedDropReportsAnErrorAndKeepsTheBook() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        model.reload()
        let ghost = ShelfID(chest: fixture.chest, name: "Ghost")
        #expect(!model.handleDrop([DragPayload.book(fixture.book).encoded], onSlot: 1, of: ghost))
        #expect(model.errorMessage != nil)
        #expect(model.shelves.first { $0.id == fixture.shelf }?.books.map(\.id) == [fixture.book])
        #expect(fixture.sound.played.isEmpty)

        let missingChest = ChestID(name: "Ghost")
        #expect(!model.handleDrop([DragPayload.shelf(fixture.shelf).encoded], onChest: missingChest))
        #expect(model.shelves.map(\.id) == [fixture.shelf])
    }

    @Test func wrongOrForeignPayloadsAreIgnored() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        model.reload()
        #expect(!model.handleDrop(["just some text"], onSlot: 2, of: fixture.shelf))
        #expect(!model.handleDrop([DragPayload.book(fixture.book).encoded], onChest: fixture.chest))
        #expect(!model.handleDrop([DragPayload.shelf(fixture.shelf).encoded], onSlot: 2, of: fixture.shelf))
    }

    @Test func shelvesShowEnoughBlocks() throws {
        let fixture = try Fixture()
        let model = ChestViewModel(chestID: fixture.chest, repository: fixture.repository, sound: fixture.sound)
        for index in 1..<6 {
            _ = model.createBook(titled: "Book \(index)", on: fixture.shelf, slot: nil)
        }
        #expect(model.blockCount(for: model.shelves[0]) == 2)
    }

    @Test func dragPayloadsRoundTrip() {
        let book = BookID(shelf: ShelfID(chest: ChestID(name: "C"), name: "S"), folderName: "B \"quoted\"")
        #expect(DragPayload(encoded: DragPayload.book(book).encoded) == .book(book))
        #expect(DragPayload(encoded: "{}") == nil)
    }
}
