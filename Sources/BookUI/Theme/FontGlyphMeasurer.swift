import BookCore
import CoreText
import Foundation
import Synchronization

/// Measures characters with the real page font, so page fitting agrees with
/// what the page text view draws (including system fallback fonts for
/// characters the pixel font lacks).
public final class FontGlyphMeasurer: GlyphMeasuring {
    private struct State {
        var font: CTFont?
        var advances: [Character: Double] = [:]
    }

    private let fontName: String
    private let size: Double
    private let state = Mutex(State())

    /// - Parameters:
    ///   - fontName: PostScript name of a registered font.
    ///   - size: Point size at which one point equals one GUI pixel (8 for the pixel font).
    public init(fontName: String, size: Double) {
        self.fontName = fontName
        self.size = size
    }

    public func advance(of character: Character) -> Double {
        state.withLock { state in
            if let cached = state.advances[character] {
                return cached
            }
            let font = state.font ?? CTFontCreateWithName(fontName as CFString, size, nil)
            state.font = font
            let attributed = NSAttributedString(
                string: String(character),
                attributes: [.font: font, .ligature: 0, .kern: 0]
            )
            let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
            state.advances[character] = width
            return width
        }
    }
}
