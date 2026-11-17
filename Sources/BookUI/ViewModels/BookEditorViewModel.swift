import BookAudio
import BookCore
import BookStorage
import Foundation
import Observation

/// The open Book and Quill: page navigation, limit-enforced editing, signing
/// and debounced autosave.
@MainActor
@Observable
public final class BookEditorViewModel: ErrorReporting {
    /// Which screen of the book is showing.
    public enum Mode: Equatable, Sendable {
        /// Writing or reading pages.
        case pages
        /// The "Enter Book Title" signing screen.
        case signing
    }

    /// Where the book is stored. Changes if signing renames the book.
    public private(set) var bookID: BookID
    /// The book content.
    public private(set) var book: Book
    /// Zero-based index of the visible page.
    public private(set) var pageIndex = 0
    /// Current screen.
    public private(set) var mode: Mode = .pages
    /// Title typed on the signing screen.
    public var signingTitle = ""
    /// Author typed on the signing screen.
    public var signingAuthor = ""
    /// Whether edits are waiting to be written to storage.
    public private(set) var hasUnsavedChanges = false
    public var errorMessage: String?

    /// The rules used to accept or clip edits.
    @ObservationIgnored public let fitter: PageFitter
    @ObservationIgnored private let repository: any LibraryRepository
    @ObservationIgnored private let sound: any SoundPlaying
    @ObservationIgnored private let preferences: any PreferencesStore
    @ObservationIgnored private let autosaveDelay: Duration
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    public init(
        bookID: BookID,
        book: Book,
        repository: any LibraryRepository,
        sound: any SoundPlaying,
        preferences: any PreferencesStore,
        fitter: PageFitter,
        autosaveDelay: Duration,
        now: @escaping () -> Date
    ) {
        self.bookID = bookID
        self.book = book
        self.repository = repository
        self.sound = sound
        self.preferences = preferences
        self.fitter = fitter
        self.autosaveDelay = autosaveDelay
        self.now = now
    }

    // MARK: Pages

    /// Whether the book can be written in (it is not signed).
    public var isEditable: Bool { !book.isSigned }
    /// Number of pages.
    public var pageCount: Int { book.pages.count }
    /// "Page X of Y", as in the game.
    public var pageLabel: String { "Page \(pageIndex + 1) of \(pageCount)" }
    /// Text of the visible page.
    public var currentText: String { book.pages[pageIndex].text }
    /// Whether the back arrow is shown.
    public var canTurnBack: Bool { pageIndex > 0 }
    /// Whether the forward arrow is shown: there is a next page, or one can be added.
    public var canTurnForward: Bool { pageIndex < pageCount - 1 || book.canAddPage }
    /// Whether turning forward will add a new page (the forward arrow on the last page).
    public var forwardAddsPage: Bool { pageIndex == pageCount - 1 && book.canAddPage }

    /// Turns to the next page, appending a blank page when on the last one.
    public func turnForward() {
        guard canTurnForward else { return }
        if forwardAddsPage {
            do {
                try book.appendPage(now: now())
            } catch {
                errorMessage = ErrorText.describe(error)
                return
            }
            scheduleSave()
        }
        pageIndex += 1
        sound.play(.pageTurn)
    }

    /// Turns to the previous page.
    public func turnBack() {
        guard canTurnBack else { return }
        pageIndex -= 1
        sound.play(.pageTurn)
    }

    // MARK: Editing

    /// Applies a typing or paste edit to the visible page.
    ///
    /// The edit is clipped to what still fits on the page (14 lines, 256 characters).
    /// - Parameters:
    ///   - range: UTF-16 range in ``currentText`` being replaced.
    ///   - replacement: The typed or pasted text.
    /// - Returns: The page's new text, or `nil` if nothing could be applied.
    public func applyEdit(replacing range: NSRange, with replacement: String) -> String? {
        guard isEditable else { return nil }
        let text = currentText
        guard let stringRange = Range(range, in: text),
            let edited = fitter.applyEdit(to: text, replacing: stringRange, with: replacement)
        else {
            return nil
        }
        return setCurrentText(edited) ? edited : nil
    }

    /// Replaces the visible page's text wholesale (used to restore a previous
    /// state). Returns `false` if the text is not acceptable.
    @discardableResult
    public func setCurrentText(_ text: String) -> Bool {
        do {
            try book.setText(text, onPage: pageIndex, fitter: fitter, now: now())
        } catch {
            return false
        }
        scheduleSave()
        return true
    }

    // MARK: Signing

    /// Opens the signing screen, pre-filled with the title and remembered author.
    public func beginSigning() {
        guard isEditable else { return }
        signingTitle = book.title
        signingAuthor = preferences.authorName ?? ""
        mode = .signing
    }

    /// Leaves the signing screen without signing.
    public func cancelSigning() {
        mode = .pages
    }

    /// Whether "Sign and Close" is enabled.
    public var canConfirmSigning: Bool {
        if case .success = NameRules.validate(signingTitle, maxLength: BookLimits.maxTitleLength),
            case .success = NameRules.validate(signingAuthor, maxLength: BookLimits.maxAuthorLength)
        {
            return true
        }
        return false
    }

    /// Signs the book, saves it and renames its folder to the new title.
    /// - Returns: `true` when the book is signed and saved; the caller closes the book.
    @discardableResult
    public func confirmSigning() -> Bool {
        let originalTitle = book.title
        do {
            try book.sign(title: signingTitle, author: signingAuthor, now: now())
        } catch {
            errorMessage = ErrorText.describe(error)
            return false
        }
        preferences.authorName = book.author
        hasUnsavedChanges = true
        guard flush() else { return false }
        if book.title != originalTitle,
            let renamed = attempt({ () throws(LibraryError) in try repository.renameBook(bookID, to: book.title) })
        {
            bookID = renamed
        }
        mode = .pages
        return true
    }

    // MARK: Saving

    /// Writes pending changes now. Returns `false` (and keeps them pending) if saving failed.
    @discardableResult
    public func flush() -> Bool {
        saveTask?.cancel()
        saveTask = nil
        guard hasUnsavedChanges else { return true }
        let saved = attempt { () throws(LibraryError) in try repository.saveBook(book, as: bookID) }
        if saved != nil {
            hasUnsavedChanges = false
            return true
        }
        return false
    }

    private func scheduleSave() {
        hasUnsavedChanges = true
        saveTask?.cancel()
        let delay = autosaveDelay
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
}
