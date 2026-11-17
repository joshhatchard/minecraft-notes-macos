/// Normalisation of raw text before it is stored on a page.
public enum PageText {
    /// Returns `text` with line endings normalised to `\n`, tabs turned into a
    /// space and every other control character removed. Pages are plain text.
    public static func sanitize(_ text: String) -> String {
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: " ")
        var result = String.UnicodeScalarView()
        for scalar in unified.unicodeScalars where scalar == "\n" || !scalar.properties.generalCategory.isControl {
            result.append(scalar)
        }
        return String(result)
    }
}

private extension Unicode.GeneralCategory {
    var isControl: Bool { self == .control }
}
