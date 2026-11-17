/// Breaks page text into rendered lines, the way the book page draws it.
///
/// Rules (greedy, like Minecraft and AppKit word wrapping):
/// - `\n` always starts a new line; a trailing `\n` produces an empty last line
///   because the caret sits on it.
/// - Words never split unless a single word is wider than the line, in which
///   case it is broken between characters.
/// - Spaces "hang": they never push a line over the edge on their own, but they
///   do count towards the width of the word that follows them.
public struct LineWrapper: Sendable {
    /// Measures each character in GUI pixels.
    public let measurer: any GlyphMeasuring
    /// Available width of one line in GUI pixels.
    public let maxWidth: Double

    /// Tolerance for floating-point advances that land exactly on the edge.
    private static let epsilon = 0.001

    public init(measurer: any GlyphMeasuring, maxWidth: Double) {
        self.measurer = measurer
        self.maxWidth = maxWidth
    }

    /// The rendered lines of `text`. Always returns at least one line.
    public func lines(for text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .flatMap { wrap(paragraph: $0) }
    }

    /// The width of `text` in GUI pixels, ignoring line breaks.
    public func width(of text: some StringProtocol) -> Double {
        text.reduce(0) { $0 + measurer.advance(of: $1) }
    }

    private func wrap(paragraph: Substring) -> [String] {
        var lines: [String] = []
        var line = ""
        var lineWidth = 0.0

        func breakLine() {
            lines.append(line)
            line = ""
            lineWidth = 0
        }

        for token in Self.tokens(of: paragraph) {
            let tokenWidth = width(of: token)
            if token.first == " " || lineWidth + tokenWidth <= maxWidth + Self.epsilon {
                line += token
                lineWidth += tokenWidth
                continue
            }
            if !line.isEmpty {
                breakLine()
            }
            for character in token {
                let advance = measurer.advance(of: character)
                if lineWidth + advance > maxWidth + Self.epsilon, !line.isEmpty {
                    breakLine()
                }
                line.append(character)
                lineWidth += advance
            }
        }
        lines.append(line)
        return lines
    }

    /// Splits a paragraph into alternating runs of spaces and non-spaces.
    private static func tokens(of paragraph: Substring) -> [Substring] {
        var tokens: [Substring] = []
        var start = paragraph.startIndex
        while start < paragraph.endIndex {
            let isSpace = paragraph[start] == " "
            var end = paragraph.index(after: start)
            while end < paragraph.endIndex, (paragraph[end] == " ") == isSpace {
                end = paragraph.index(after: end)
            }
            tokens.append(paragraph[start..<end])
            start = end
        }
        return tokens
    }
}
