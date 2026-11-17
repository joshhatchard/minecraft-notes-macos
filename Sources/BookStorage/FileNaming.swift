import BookCore
import Foundation

/// Turns user-entered names into safe, unique folder names.
enum FileNaming {
    /// Longest folder name we produce (well under every file system limit).
    static let maxLength = 80
    /// Used when nothing printable is left after sanitising.
    static let fallbackName = "Untitled"
    /// Characters that are illegal or troublesome on macOS, Windows or iCloud.
    private static let forbidden: Set<Character> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]

    /// Replaces forbidden and control characters with `-`, trims spaces and
    /// leading/trailing dots, and caps the length.
    static func sanitize(_ name: String) -> String {
        var result = String(name.map { character -> Character in
            if forbidden.contains(character) { return "-" }
            if character.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) { return "-" }
            return character
        })
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix(".") { result.removeFirst() }
        result = String(result.prefix(maxLength))
        while let last = result.last, last == "." || last.isWhitespace { result.removeLast() }
        return result.isEmpty ? fallbackName : result
    }

    /// Returns `base`, or `base 2`, `base 3` … so that `base + suffix` does not
    /// collide (case-insensitively) with any name in `existing`.
    static func unique(_ base: String, suffix: String = "", among existing: some Sequence<String>) -> String {
        let taken = Set(existing.map { $0.lowercased() })
        if !taken.contains((base + suffix).lowercased()) {
            return base
        }
        var counter = 2
        while taken.contains("\(base) \(counter)\(suffix)".lowercased()) {
            counter += 1
        }
        return "\(base) \(counter)"
    }

    /// Validates a container (chest/shelf) name and returns a safe folder base name.
    static func containerFolderName(for name: String) throws(LibraryError) -> String {
        switch NameRules.validate(name, maxLength: BookLimits.maxContainerNameLength) {
        case .success(let valid): return sanitize(valid)
        case .failure(let issue): throw .invalidName(issue)
        }
    }

    /// Validates a book title, returning the trimmed title.
    static func validTitle(_ title: String) throws(LibraryError) -> String {
        switch NameRules.validate(title, maxLength: BookLimits.maxTitleLength) {
        case .success(let valid): return valid
        case .failure(let issue): throw .invalidName(issue)
        }
    }

    /// Orders `actual` names by a stored order; names missing from the stored
    /// order follow, sorted the way Finder sorts.
    static func ordered(_ actual: [String], by stored: [String]) -> [String] {
        let present = Set(actual)
        var seen = Set<String>()
        var result = stored.filter { present.contains($0) && seen.insert($0).inserted }
        let rest = actual.filter { !seen.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        result.append(contentsOf: rest)
        return result
    }
}
