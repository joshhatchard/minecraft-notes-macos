import Foundation

/// Why a user-entered name was rejected.
public enum NameIssue: Error, Equatable, Sendable {
    /// The name is empty or only whitespace.
    case empty
    /// The name is longer than the allowed maximum.
    case tooLong(max: Int)
    /// The name contains a line break or other control character.
    case containsControlCharacters
}

/// Validation of names typed by the user (chests, shelves, book titles, authors).
public enum NameRules {
    /// Trims surrounding whitespace and validates the result.
    /// - Returns: The trimmed name, or the reason it is not acceptable.
    public static func validate(_ name: String, maxLength: Int) -> Result<String, NameIssue> {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= maxLength else { return .failure(.tooLong(max: maxLength)) }
        guard !trimmed.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            return .failure(.containsControlCharacters)
        }
        return .success(trimmed)
    }
}
