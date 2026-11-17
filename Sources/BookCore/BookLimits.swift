/// The fixed rules of a Book and Quill. These are deliberate product limits,
/// not technical ones: they are "the whole charm" of the app.
public enum BookLimits {
    /// Maximum number of pages in one book.
    public static let maxPages = 100
    /// Maximum number of rendered lines on one page, after word wrapping.
    public static let linesPerPage = 14
    /// Maximum number of characters (grapheme clusters, newlines included) on one page.
    public static let charactersPerPage = 256
    /// Width of the writable page area in GUI pixels (one texel of the book texture).
    public static let lineWidth: Double = 114
    /// Maximum length of a book title.
    public static let maxTitleLength = 32
    /// Maximum length of an author name.
    public static let maxAuthorLength = 32
    /// Maximum length of a chest or shelf name.
    public static let maxContainerNameLength = 64
}
