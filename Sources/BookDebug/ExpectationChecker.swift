import AppKit
import BookUI

/// Compares the running app against a ``ScenarioExpectation``.
@MainActor
struct ExpectationChecker {
    let app: AppModel
    let window: NSWindow
    let libraryRoot: URL

    /// Human-readable mismatches; empty when everything matches.
    func problems(with expected: ScenarioExpectation) -> [String] {
        var problems: [String] = []
        func check<T: Equatable>(_ label: String, _ want: T?, _ have: T) {
            if let want, want != have { problems.append("\(label): expected \(want), got \(have)") }
        }

        check("route", expected.route, routeName)
        check("chests", expected.chests, app.chestList.chests.map(\.name))
        check("shelves", expected.shelves, app.chest?.shelves.map(\.name) ?? [])
        if let books = expected.books {
            for (shelfName, want) in books {
                let shelf = app.chest?.shelves.first { $0.name == shelfName }
                check("books on \(shelfName)", want, shelf?.books.map { "\($0.slot):\($0.title)" } ?? ["<no shelf>"])
            }
        }
        check("page text", expected.pageText, app.editor?.currentText ?? "<no book open>")
        check("page label", expected.pageLabel, app.editor?.pageLabel ?? "<no book open>")
        check("signed", expected.signed, app.editor?.book.isSigned ?? false)
        check("sheet", expected.sheet, window.attachedSheet != nil)
        check("typing into page", expected.typingIntoPage, isTypingIntoPage)
        if let file = expected.file {
            let url = libraryRoot.appending(path: file.path)
            let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? "<missing \(file.path)>"
            if !contents.contains(file.contains) {
                problems.append("file \(file.path): expected to contain \(file.contains.debugDescription), has \(contents.debugDescription)")
            }
        }
        return problems
    }

    private var routeName: String {
        switch app.route {
        case .chests: "chests"
        case .chest: "chest"
        case .book: "book"
        }
    }

    /// The page editor (a text view that is not a text field's field editor) has focus.
    private var isTypingIntoPage: Bool {
        guard let textView = window.firstResponder as? NSTextView else { return false }
        return !textView.isFieldEditor && textView.isEditable
    }
}
