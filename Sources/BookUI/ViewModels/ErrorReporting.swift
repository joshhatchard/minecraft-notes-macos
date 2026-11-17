import BookCore
import BookStorage

/// A view model that surfaces failures as a user-facing message.
@MainActor
protocol ErrorReporting: AnyObject {
    /// Message shown in an alert; cleared when dismissed.
    var errorMessage: String? { get set }
}

extension ErrorReporting {
    /// Runs a repository operation, turning a failure into ``errorMessage``.
    /// - Returns: The result, or `nil` if the operation failed.
    func attempt<T>(_ operation: () throws(LibraryError) -> T) -> T? {
        do {
            return try operation()
        } catch {
            errorMessage = error.errorDescription
            return nil
        }
    }

    /// Returns the current error message and clears it, so a sheet can show it
    /// inline instead of the screen raising an alert.
    func takeErrorMessage() -> String? {
        defer { errorMessage = nil }
        return errorMessage
    }
}

/// User-facing descriptions of domain errors.
enum ErrorText {
    static func describe(_ error: BookError) -> String {
        switch error {
        case .signed: "This book is signed and can no longer be edited."
        case .pageLimitReached: "A book can hold at most \(BookLimits.maxPages) pages."
        case .pageIndexOutOfRange: "That page does not exist."
        case .pageOverflow: "That does not fit on the page."
        case .invalidTitle(let issue): "Title: \(describe(issue))"
        case .invalidAuthor(let issue): "Author: \(describe(issue))"
        }
    }

    static func describe(_ issue: NameIssue) -> String {
        switch issue {
        case .empty: "please enter a name."
        case .tooLong(let max): "at most \(max) characters."
        case .containsControlCharacters: "no line breaks allowed."
        }
    }
}
