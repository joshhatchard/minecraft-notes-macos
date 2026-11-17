import AppKit
import BookAudio
import BookCore
import BookStorage
import SwiftUI
import Testing

@testable import BookUI

private let signingTestDate = Date(timeIntervalSince1970: 1_700_000_000)

/// The book screen in a real window: an unsigned book is writable and offers
/// "Sign"; after signing, the text view is read-only and the screen says so.
@MainActor
@Suite("Signing in the book screen", .serialized)
struct SigningUITests {
    private static let windowSize = CGSize(width: 900, height: 700)

    private func makeApp() throws -> (app: AppModel, editor: BookEditorViewModel) {
        let repository = InMemoryLibraryRepository(now: { signingTestDate })
        let chest = try repository.createChest(named: "Term")
        let shelf = try repository.createShelf(named: "Maths", in: chest)
        let bookID = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)
        let app = AppModel(
            dependencies: AppDependencies(
                makeRepository: { _ in repository },
                defaultLibraryRoot: URL(filePath: "/tmp/unused"),
                sound: SilentSoundPlayer(),
                preferences: InMemoryPreferences(authorName: "Josh"),
                fitter: PageFitter(),
                autosaveDelay: .seconds(60),
                now: { signingTestDate }
            ))
        app.openBook(bookID)
        return (app, try #require(app.editor))
    }

    private func host(_ app: AppModel, _ editor: BookEditorViewModel) -> HostedView {
        HostedView(size: Self.windowSize) { BookEditorScreen(app: app, model: editor) }
    }

    private func pageTextView(in hosted: HostedView) -> NSTextView? {
        func find(_ view: NSView) -> NSTextView? {
            if let text = view as? PageNSTextView { return text }
            return view.subviews.lazy.compactMap(find).first
        }
        return hosted.window.contentView.flatMap(find)
    }

    @Test func unsignedBookIsWritableAndOffersSign() throws {
        let (app, editor) = try makeApp()
        let hosted = host(app, editor)
        defer { hosted.close() }

        #expect(pageTextView(in: hosted)?.isEditable == true)
        #expect(hosted.targets.target(UITargetID.signButton) != nil)
        #expect(hosted.targets.target(UITargetID.signedBadge) == nil)
    }

    @Test func signingThroughTheUILocksTheBook() throws {
        let (app, editor) = try makeApp()
        _ = editor.applyEdit(replacing: NSRange(location: 0, length: 0), with: "Notes")
        let hosted = host(app, editor)
        defer { hosted.close() }

        #expect(hosted.click(UITargetID.signButton))
        #expect(editor.mode == .signing)
        editor.signingTitle = "Final"
        hosted.settle()
        #expect(hosted.click(UITargetID.signConfirm))

        #expect(editor.book.isSigned)
        #expect(app.route == .chest(editor.bookID.shelf.chest))
    }

    @Test func signedBookIsReadOnlyWithAVisibleBadge() throws {
        let (app, editor) = try makeApp()
        _ = editor.applyEdit(replacing: NSRange(location: 0, length: 0), with: "Notes")
        editor.beginSigning()
        editor.signingTitle = "Final"
        #expect(editor.confirmSigning())
        let hosted = host(app, editor)
        defer { hosted.close() }

        let textView = try #require(pageTextView(in: hosted))
        #expect(textView.string == "Notes")
        #expect(!textView.isEditable)
        #expect(hosted.targets.target(UITargetID.signedBadge) != nil)
        #expect(hosted.targets.target(UITargetID.signButton) == nil)
        #expect(hosted.targets.target(UITargetID.doneButton) != nil)
    }
}
