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
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        configure(container, scale: scale)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        return renderedLineCount(in: layoutManager, container: container)
    }
}
