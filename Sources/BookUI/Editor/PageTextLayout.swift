import AppKit
import BookCore

/// Typography of the writable page, shared by the text view and by tests that
/// check AppKit wraps text exactly like the page fitter.
@MainActor
enum PageTextLayout {
    /// Writable width in GUI pixels.
    static let width = CGFloat(BookLimits.lineWidth)
    /// Writable height in GUI pixels (14 lines).
    static let height = PixelTheme.lineHeight * CGFloat(BookLimits.linesPerPage)
    /// Distance from the top of a 9 px line to its baseline, in GUI pixels.
    /// The pixel font draws glyphs up to 8 px above the baseline and 1 px
    /// below it, so this fills the line exactly.
    static let baseline: CGFloat = 8

    /// Text attributes for page text at `scale`.
    static func attributes(scale: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = PixelTheme.lineHeight * scale
        paragraph.maximumLineHeight = PixelTheme.lineHeight * scale
        paragraph.lineBreakMode = .byWordWrapping
        return [
            .font: FontRegistry.pixelFont(size: PixelTheme.fontSize * scale),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
            .ligature: 0,
            .kern: 0,
        ]
    }

    /// Configures a text container to match the page.
    static func configure(_ container: NSTextContainer, scale: CGFloat) {
        container.lineFragmentPadding = 0
        container.widthTracksTextView = false
        container.size = CGSize(width: width * scale, height: .greatestFiniteMagnitude)
    }

    /// Number of line fragments AppKit lays `text` out in, counting the empty
    /// line after a trailing newline (where the caret sits).
    static func renderedLineCount(in layoutManager: NSLayoutManager, container: NSTextContainer) -> Int {
        layoutManager.ensureLayout(for: container)
        let glyphs = layoutManager.glyphRange(for: container)
        var lines = 0
        layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { _, _, _, _, _ in
            lines += 1
        }
        if layoutManager.extraLineFragmentTextContainer != nil {
            lines += 1
        }
        return max(lines, 1)
    }

    /// Lays out `text` off-screen with the page typography and counts its lines.
    static func renderedLineCount(of text: String, scale: CGFloat) -> Int {
        let storage = NSTextStorage(string: text, attributes: attributes(scale: scale))
        let layoutManager = PageLayoutManager(scale: scale)
        let container = NSTextContainer()
        configure(container, scale: scale)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        return renderedLineCount(in: layoutManager, container: container)
    }
}

/// Lays page lines out with the baseline where the pixel font needs it.
///
/// With a fixed 9 px line height TextKit puts the baseline 7 px down, but the
/// font's glyphs reach 8 px above it, so the first line's top pixel row (the
/// dots on i, the top bar of D) fell outside the text container and was cut
/// off. Lower lines hid the problem by drawing into the line above.
final class PageLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    private let baseline: CGFloat

    @MainActor
    init(scale: CGFloat) {
        baseline = PageTextLayout.baseline * scale
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("PageLayoutManager is not decoded from archives")
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        baselineOffset.pointee = baseline
        return true
    }
}
