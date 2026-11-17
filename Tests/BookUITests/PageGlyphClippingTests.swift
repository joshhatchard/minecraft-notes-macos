import AppKit
import Testing

@testable import BookUI

/// Renders the real page text view and checks no glyph pixels are cut off.
///
/// Regression: the first line lost its top pixel row (the dots of i, the top
/// bar of D), because the page's 9 px line height is shorter than the font's
/// ascent and the first line's glyph tops fell outside the drawn area.
@MainActor
@Suite("Page glyphs are not clipped")
struct PageGlyphClippingTests {
    init() {
        FontRegistry.registerBundledFonts()
    }

    /// Height in GUI pixels of the ink on the first line of `text`.
    func inkHeight(of text: String, scale: CGFloat) -> CGFloat {
        let textView = PageTextView.makePageTextView(scale: scale)
        textView.frame = CGRect(
            x: 0,
            y: 0,
            width: PageTextLayout.width * scale,
            height: PageTextLayout.height * scale
        )
        textView.string = text
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        guard let rep = textView.bitmapImageRepForCachingDisplay(in: textView.bounds) else { return 0 }
        textView.cacheDisplay(in: textView.bounds, to: rep)

        var rows: [Int] = []
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.5, color.brightnessComponent < 0.5 {
                    rows.append(y)
                    break
                }
            }
        }
        guard let top = rows.first, let bottom = rows.last else { return 0 }
        let pixelsPerPoint = CGFloat(rep.pixelsHigh) / textView.bounds.height
        return CGFloat(bottom - top + 1) / pixelsPerPoint / scale
    }

    @Test(arguments: [1, 2, 3] as [CGFloat])
    func capitalDIsSevenPixelsTall(scale: CGFloat) {
        #expect(inkHeight(of: "D", scale: scale) == 7)
    }

    @Test(arguments: [1, 2, 3] as [CGFloat])
    func dottedIIsSevenPixelsTall(scale: CGFloat) {
        #expect(inkHeight(of: "i", scale: scale) == 7)
    }
}
