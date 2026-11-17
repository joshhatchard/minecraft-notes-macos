/// Result of checking a page's text against the page limits.
public enum PageFit: Equatable, Sendable {
    /// The text fits on one page.
    case fits
    /// The text has more characters than allowed; carries the actual count.
    case tooManyCharacters(Int)
    /// The text wraps onto more lines than allowed; carries the actual count.
    case tooManyLines(Int)
}

/// Enforces the per-page limits: at most 256 characters and 14 rendered lines.
public struct PageFitter: Sendable {
    /// Wraps text into rendered lines.
    public let wrapper: LineWrapper
    /// Maximum rendered lines per page.
    public let maxLines: Int
    /// Maximum characters per page.
    public let maxCharacters: Int

    public init(
        measurer: any GlyphMeasuring = MinecraftGlyphMetrics(),
        lineWidth: Double = BookLimits.lineWidth,
        maxLines: Int = BookLimits.linesPerPage,
        maxCharacters: Int = BookLimits.charactersPerPage
    ) {
        self.wrapper = LineWrapper(measurer: measurer, maxWidth: lineWidth)
        self.maxLines = maxLines
        self.maxCharacters = maxCharacters
    }

    /// Number of characters as the limit counts them (grapheme clusters, newlines included).
    public func characterCount(of text: String) -> Int {
        text.count
    }

    /// Number of rendered lines after word wrapping.
    public func lineCount(of text: String) -> Int {
        wrapper.lines(for: text).count
    }

    /// Checks `text` against both limits. Characters are checked first.
    public func check(_ text: String) -> PageFit {
        let characters = characterCount(of: text)
        if characters > maxCharacters {
            return .tooManyCharacters(characters)
        }
        let lines = lineCount(of: text)
        if lines > maxLines {
            return .tooManyLines(lines)
        }
        return .fits
    }

    /// Whether `text` fits on one page.
    public func fits(_ text: String) -> Bool {
        check(text) == .fits
    }

    /// Whether `candidate` is acceptable as a replacement for `current`: either it
    /// fits, or it is no larger than `current` by both measures (so a page that was
    /// over the limit when loaded can still be trimmed down).
    public func accepts(_ candidate: String, replacing current: String) -> Bool {
        if fits(candidate) {
            return true
        }
        return characterCount(of: candidate) <= characterCount(of: current)
            && lineCount(of: candidate) <= lineCount(of: current)
    }

    /// Applies a typing or paste edit while enforcing the limits.
    ///
    /// The replacement is sanitised first. If the whole edit fits it is applied
    /// as-is; otherwise the longest prefix of the replacement that still fits is
    /// inserted, so a long paste fills the page instead of being dropped.
    ///
    /// - Returns: The new page text, or `nil` when no part of the edit can be applied.
    public func applyEdit(
        to text: String,
        replacing range: Range<String.Index>,
        with replacement: String
    ) -> String? {
        let insertion = Array(PageText.sanitize(replacement))
        func result(insertingFirst count: Int) -> String {
            var edited = text
            edited.replaceSubrange(range, with: insertion.prefix(count))
            return edited
        }

        let full = result(insertingFirst: insertion.count)
        if accepts(full, replacing: text) {
            return full == text ? nil : full
        }

        var low = 0
        var high = insertion.count - 1
        var best: String?
        while low <= high {
            let middle = (low + high) / 2
            let candidate = result(insertingFirst: middle)
            if accepts(candidate, replacing: text) {
                best = candidate
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        guard let best, best != text else {
            return nil
        }
        return best
    }
}
