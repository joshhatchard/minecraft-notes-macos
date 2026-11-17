import Foundation

/// One page of a book: plain text.
public struct Page: Equatable, Sendable {
    /// The page text, `\n` separated.
    public var text: String

    public init(text: String = "") {
        self.text = text
    }
}

/// Why an edit to a book was refused.
public enum BookError: Error, Equatable, Sendable {
    /// The book is signed and therefore read-only.
    case signed
    /// The book already has ``BookLimits/maxPages`` pages.
    case pageLimitReached
    /// The page index does not exist.
    case pageIndexOutOfRange(Int)
    /// The text does not fit on a page.
    case pageOverflow(PageFit)
    /// The title is not valid.
    case invalidTitle(NameIssue)
    /// The author name is not valid.
    case invalidAuthor(NameIssue)
}

/// A Book and Quill: a titled stack of pages that can be signed to lock it.
///
/// All mutation goes through methods that enforce the rules, so a `Book` value
/// can never gain an overflowing page or be edited once signed.
public struct Book: Equatable, Sendable {
    /// Display title. Also used to name the book's folder.
    public private(set) var title: String
    /// Author name; set when the book is signed.
    public private(set) var author: String
    /// Whether the book has been signed. Signed books are read-only.
    public private(set) var isSigned: Bool
    /// When the book was created.
    public let createdAt: Date
    /// When the book content or metadata last changed.
    public private(set) var updatedAt: Date
    /// The pages. Never empty.
    public private(set) var pages: [Page]

    /// Creates a book. An empty `pages` array becomes a single blank page.
    /// Loaded content is accepted as-is (even if it breaks limits) so no data is lost;
    /// limits apply to every subsequent edit.
    public init(
        title: String,
        author: String = "",
        isSigned: Bool = false,
        createdAt: Date,
        updatedAt: Date? = nil,
        pages: [Page] = []
    ) {
        self.title = title
        self.author = author
        self.isSigned = isSigned
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.pages = pages.isEmpty ? [Page()] : pages
    }

    /// Whether another page can be added.
    public var canAddPage: Bool {
        !isSigned && pages.count < BookLimits.maxPages
    }

    /// Replaces the text of the page at `index`.
    ///
    /// The text is sanitised and must fit on the page (or be no larger than the
    /// current text, so over-full imported pages can be trimmed).
    public mutating func setText(_ text: String, onPage index: Int, fitter: PageFitter, now: Date) throws(BookError) {
        guard !isSigned else { throw .signed }
        guard pages.indices.contains(index) else { throw .pageIndexOutOfRange(index) }
        let sanitized = PageText.sanitize(text)
        guard sanitized != pages[index].text else { return }
        guard fitter.accepts(sanitized, replacing: pages[index].text) else {
            throw .pageOverflow(fitter.check(sanitized))
        }
        pages[index].text = sanitized
        updatedAt = now
    }

    /// Appends a blank page and returns its index.
    @discardableResult
    public mutating func appendPage(now: Date) throws(BookError) -> Int {
        guard !isSigned else { throw .signed }
        guard pages.count < BookLimits.maxPages else { throw .pageLimitReached }
        pages.append(Page())
        updatedAt = now
        return pages.count - 1
    }

    /// Changes the title. Allowed on signed books too: the title is the label
    /// the book is filed under, not part of its locked content.
    public mutating func rename(to newTitle: String, now: Date) throws(BookError) {
        title = try Self.validatedTitle(newTitle)
        updatedAt = now
    }

    /// Signs the book with a title and author, making it permanently read-only.
    public mutating func sign(title newTitle: String, author newAuthor: String, now: Date) throws(BookError) {
        guard !isSigned else { throw .signed }
        let validTitle = try Self.validatedTitle(newTitle)
        let validAuthor: String
        switch NameRules.validate(newAuthor, maxLength: BookLimits.maxAuthorLength) {
        case .success(let name): validAuthor = name
        case .failure(let issue): throw .invalidAuthor(issue)
        }
        title = validTitle
        author = validAuthor
        isSigned = true
        updatedAt = now
    }

    private static func validatedTitle(_ title: String) throws(BookError) -> String {
        switch NameRules.validate(title, maxLength: BookLimits.maxTitleLength) {
        case .success(let name): return name
        case .failure(let issue): throw .invalidTitle(issue)
        }
    }
}
