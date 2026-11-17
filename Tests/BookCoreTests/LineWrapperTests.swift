import BookCore
import Testing

@Suite("Line wrapping")
struct LineWrapperTests {
    let wrapper = LineWrapper(measurer: MinecraftGlyphMetrics(), maxWidth: BookLimits.lineWidth)

    @Test func emptyTextIsOneEmptyLine() {
        #expect(wrapper.lines(for: "") == [""])
    }

    @Test func glyphWidthsMatchTheMinecraftFont() {
        let metrics = MinecraftGlyphMetrics()
        #expect(metrics.advance(of: "a") == 6)
        #expect(metrics.advance(of: "i") == 2)
        #expect(metrics.advance(of: "l") == 3)
        #expect(metrics.advance(of: " ") == 4)
        #expect(metrics.advance(of: "@") == 7)
        #expect(metrics.advance(of: "é") == MinecraftGlyphMetrics.fallbackAdvance)
    }

    @Test func textExactlyAsWideAsTheLineFits() {
        // 19 × 6 = 114 pixels, exactly the line width.
        let text = String(repeating: "a", count: 19)
        #expect(wrapper.lines(for: text) == [text])
    }

    @Test func overlongWordBreaksBetweenCharacters() {
        let text = String(repeating: "a", count: 20)
        #expect(wrapper.lines(for: text) == [String(repeating: "a", count: 19), "a"])
    }

    @Test func wordsWrapWhole() {
        // "aaaaaaaaa" is 54 px; two of them plus a space is 112 px; a third word must wrap.
        let word = String(repeating: "a", count: 9)
        let lines = wrapper.lines(for: "\(word) \(word) \(word)")
        #expect(lines == ["\(word) \(word) ", word])
    }

    @Test func narrowGlyphsFitMore() {
        // "i" is 2 px wide: 57 of them fill 114 px exactly.
        let text = String(repeating: "i", count: 57)
        #expect(wrapper.lines(for: text).count == 1)
        #expect(wrapper.lines(for: text + "i").count == 2)
    }

    @Test func newlinesStartNewLines() {
        #expect(wrapper.lines(for: "a\nb\n\nc") == ["a", "b", "", "c"])
    }

    @Test func trailingNewlineAddsAnEmptyCaretLine() {
        #expect(wrapper.lines(for: "a\n") == ["a", ""])
    }

    @Test func trailingSpacesHangWithoutWrapping() {
        let text = String(repeating: "a", count: 19) + "     "
        #expect(wrapper.lines(for: text).count == 1)
    }

    @Test func unicodeCharactersAreMeasuredAsWholeGraphemes() {
        // Each emoji is one Character with the fallback width of 6 px.
        let text = String(repeating: "👍🏽", count: 20)
        let lines = wrapper.lines(for: text)
        #expect(lines.count == 2)
        #expect(lines[0].count == 19)
    }

    @Test func widthSumsAdvances() {
        #expect(wrapper.width(of: "ai ") == 12)
    }
}
