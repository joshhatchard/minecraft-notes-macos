import BookCore
import BookStorage
import Foundation
import Testing

@testable import BookUI

/// The whole writing journey through the real view models and the real
/// file-system repository in a temporary folder, including quit and relaunch.
@MainActor
@Suite("Writing flow on disk")
struct WritingFlowTests {
    /// A library folder that survives several "launches" of the app.
    @MainActor
    private final class Library {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "BookAndQuillFlow-\(UUID().uuidString)", directoryHint: .isDirectory)
        let sound = SoundSpy()
        let preferences = InMemoryPreferences(authorName: "Josh")

        deinit { try? FileManager.default.removeItem(at: folder) }

        /// Starts a fresh app model over the same folder, like relaunching the app.
        func launch() -> AppModel {
            let folder = self.folder
            return AppModel(
                dependencies: AppDependencies(
                    makeRepository: { FileSystemLibraryRepository(rootURL: $0, deletionMode: .removePermanently) },
                    defaultLibraryRoot: folder,
                    sound: sound,
                    preferences: preferences,
                    fitter: PageFitter(),
                    autosaveDelay: .seconds(60),
                    now: { testDate }
                ))
        }

        func pageFile(_ relativePath: String) throws -> String {
            try String(contentsOf: folder.appending(path: relativePath), encoding: .utf8)
        }
    }

    private func type(_ text: String, into app: AppModel) {
        let editor = app.editor!
        let end = (editor.currentText as NSString).length
        _ = editor.applyEdit(replacing: NSRange(location: end, length: 0), with: text)
    }

    /// Creates chest "Term", shelf "Maths" and a book in slot 2, then opens the book.
    private func createAndOpenBook(in app: AppModel) throws -> BookID {
        #expect(app.chestList.createChest(named: "Term"))
        let chestID = try #require(app.chestList.chests.first?.id)
        app.openChest(chestID)
        let chest = try #require(app.chest)
        #expect(chest.createShelf(named: "Maths"))
        let shelfID = try #require(chest.shelves.first?.id)
        let bookID = try #require(chest.createBook(titled: "Calculus", on: shelfID, slot: 2))
        app.openBook(bookID)
        return bookID
    }

    @Test func textSurvivesGoingBackReopeningAndRelaunching() throws {
        let library = Library()
        var app = library.launch()
        let bookID = try createAndOpenBook(in: app)
        #expect(app.route == .book(bookID))

        type("Page one.", into: app)
        app.editor?.turnForward()
        type("Page two.", into: app)
        app.editor?.turnBack()
        #expect(app.editor?.currentText == "Page one.")

        app.goBack()
        #expect(app.route == .chest(bookID.shelf.chest))

        app.openBook(bookID)
        #expect(app.editor?.pageLabel == "Page 1 of 2")
        #expect(app.editor?.currentText == "Page one.")
        app.editor?.turnForward()
        #expect(app.editor?.currentText == "Page two.")
        #expect(try library.pageFile("Term/Maths/Calculus.book/pages/001.md") == "Page one.")
        #expect(try library.pageFile("Term/Maths/Calculus.book/pages/002.md") == "Page two.")

        // Quit with an unsaved edit, then relaunch.
        type(" More.", into: app)
        #expect(app.flushPendingChanges())
        app = library.launch()
        #expect(app.chestList.chests.map(\.name) == ["Term"])
        app.openChest(app.chestList.chests[0].id)
        app.openBook(bookID)
        #expect(app.editor?.pageCount == 2)
        #expect(app.editor?.currentText == "Page one.")
        app.editor?.turnForward()
        #expect(app.editor?.currentText == "Page two. More.")
    }

    @Test func pageLimitsHoldAndPersist() throws {
        let library = Library()
        var app = library.launch()
        let bookID = try createAndOpenBook(in: app)

        // 256 characters per page.
        type(String(repeating: "i", count: 300), into: app)
        #expect(app.editor?.currentText.count == 256)

        // 14 lines per page.
        app.editor?.turnForward()
        type(String(repeating: "\n", count: 30) + "x", into: app)
        #expect(app.editor?.currentText.filter { $0 == "\n" }.count == 13)

        // 100 pages per book.
        for _ in 0..<150 { app.editor?.turnForward() }
        #expect(app.editor?.pageCount == 100)
        #expect(app.editor?.canTurnForward == false)
        type("The end", into: app)
        #expect(app.flushPendingChanges())

        app = library.launch()
        app.openBook(bookID)
        let stored = try #require(app.editor)
        #expect(stored.pageCount == 100)
        #expect(stored.book.pages[0].text.count == 256)
        #expect(stored.book.pages[1].text.filter { $0 == "\n" }.count == 13)
        #expect(stored.book.pages[99].text == "The end")
    }

    @Test func signedBookStaysLockedAfterRelaunch() throws {
        let library = Library()
        var app = library.launch()
        let bookID = try createAndOpenBook(in: app)
        type("Final notes", into: app)
        let editor = try #require(app.editor)
        editor.beginSigning()
        editor.signingTitle = "Limits"
        editor.signingAuthor = "Josh"
        #expect(editor.confirmSigning())
        let signedID = editor.bookID
        app.goBack()

        app = library.launch()
        app.openChest(bookID.shelf.chest)
        app.openBook(signedID)
        #expect(app.editor?.book.title == "Limits")
        #expect(app.editor?.isEditable == false)
        #expect(app.editor?.currentText == "Final notes")
    }
}
