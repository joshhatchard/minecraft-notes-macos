import BookAudio
import BookCore
import BookStorage
import Foundation
import Testing

@testable import BookUI

@MainActor
@Suite("Book editor view model")
struct BookEditorViewModelTests {
    private func insert(_ text: String, into editor: BookEditorViewModel) -> String? {
        let end = (editor.currentText as NSString).length
        return editor.applyEdit(replacing: NSRange(location: end, length: 0), with: text)
    }

    @Test func startsOnTheFirstPage() throws {
        let editor = try Fixture().makeEditor()
        #expect(editor.pageIndex == 0)
        #expect(editor.pageLabel == "Page 1 of 1")
        #expect(!editor.canTurnBack)
        #expect(editor.canTurnForward)
        #expect(editor.forwardAddsPage)
    }

    @Test func turningForwardOnTheLastPageAddsAPage() throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor()
        editor.turnForward()
        #expect(editor.pageCount == 2)
        #expect(editor.pageIndex == 1)
        #expect(editor.pageLabel == "Page 2 of 2")
        #expect(editor.hasUnsavedChanges)
        editor.turnBack()
        #expect(editor.pageIndex == 0)
        #expect(!editor.forwardAddsPage)
        editor.turnForward()
        #expect(editor.pageCount == 2)
        #expect(fixture.sound.played == [.pageTurn, .pageTurn, .pageTurn])
    }

    @Test func cannotGoPastOneHundredPages() throws {
        let editor = try Fixture().makeEditor()
        for _ in 0..<150 {
            editor.turnForward()
        }
        #expect(editor.pageCount == 100)
        #expect(editor.pageIndex == 99)
        #expect(!editor.canTurnForward)
    }

    @Test func cannotTurnBackFromTheFirstPage() throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor()
        editor.turnBack()
        #expect(editor.pageIndex == 0)
        #expect(fixture.sound.played.isEmpty)
    }

    @Test func editsWithinLimitsAreApplied() throws {
        let editor = try Fixture().makeEditor()
        #expect(insert("Hello", into: editor) == "Hello")
        #expect(insert(" world", into: editor) == "Hello world")
        #expect(editor.currentText == "Hello world")
    }

    @Test func editsBeyondTheLimitAreRejectedOrClipped() throws {
        let editor = try Fixture().makeEditor()
        #expect(insert(String(repeating: "i", count: 300), into: editor)?.count == 256)
        #expect(insert("i", into: editor) == nil)
        #expect(editor.currentText.count == 256)
    }

    @Test func invalidRangesAreRejected() throws {
        let editor = try Fixture().makeEditor()
        #expect(editor.applyEdit(replacing: NSRange(location: 10, length: 2), with: "x") == nil)
    }

    @Test func flushWritesToTheRepository() throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor()
        _ = insert("Saved text", into: editor)
        #expect(try fixture.repository.loadBook(fixture.book).pages[0].text.isEmpty)
        #expect(editor.flush())
        #expect(!editor.hasUnsavedChanges)
        #expect(try fixture.repository.loadBook(fixture.book).pages[0].text == "Saved text")
    }

    @Test func autosaveRunsAfterTheDebounce() async throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor(autosaveDelay: .milliseconds(20))
        _ = insert("a", into: editor)
        _ = insert("b", into: editor)
        #expect(editor.hasUnsavedChanges)
        for _ in 0..<100 where editor.hasUnsavedChanges {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!editor.hasUnsavedChanges)
        #expect(try fixture.repository.loadBook(fixture.book).pages[0].text == "ab")
    }

    @Test func signingLocksAndRenames() throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor()
        _ = insert("Draft", into: editor)
        editor.beginSigning()
        #expect(editor.mode == .signing)
        #expect(editor.signingTitle == "Week 1")
        #expect(editor.signingAuthor == "Josh")
        editor.signingTitle = "Kinematics"
        editor.signingAuthor = "J. Hatchard"
        #expect(editor.confirmSigning())

        #expect(!editor.isEditable)
        #expect(editor.mode == .pages)
        #expect(editor.bookID.folderName == "Kinematics")
        #expect(fixture.preferences.authorName == "J. Hatchard")
        let stored = try fixture.repository.loadBook(editor.bookID)
        #expect(stored.isSigned)
        #expect(stored.pages[0].text == "Draft")
        #expect(insert("more", into: editor) == nil)
        #expect(!editor.forwardAddsPage)
        #expect(!editor.canTurnForward)
    }

    @Test func signingNeedsATitle() throws {
        let editor = try Fixture().makeEditor()
        editor.beginSigning()
        editor.signingTitle = "   "
        #expect(!editor.canConfirmSigning)
        #expect(!editor.confirmSigning())
        #expect(editor.errorMessage != nil)
        #expect(editor.isEditable)
    }

    @Test func cancellingSigningChangesNothing() throws {
        let editor = try Fixture().makeEditor()
        editor.beginSigning()
        editor.cancelSigning()
        #expect(editor.mode == .pages)
        #expect(editor.isEditable)
    }

    @Test func saveFailureKeepsChangesPending() throws {
        let fixture = try Fixture()
        let editor = try fixture.makeEditor()
        _ = insert("Important", into: editor)
        try fixture.repository.deleteBook(fixture.book)
        #expect(!editor.flush())
        #expect(editor.hasUnsavedChanges)
        #expect(editor.errorMessage != nil)
    }
}
