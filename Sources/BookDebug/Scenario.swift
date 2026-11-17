import Foundation

/// A scripted walk through the interface, loaded from JSON.
///
/// ```json
/// { "name": "first-book",
///   "steps": [ {"click": "new-chest"}, {"type": "Semester 1"}, {"key": "return"},
///              {"snapshot": "chest-created"},
///              {"expect": {"route": "chests", "chests": ["Semester 1"]}} ] }
/// ```
/// See docs/DEBUGGING.md for every step.
public struct Scenario: Decodable, Sendable {
    public let name: String
    /// Scenarios naming the same library share one temporary library folder
    /// during `make snapshot`, so a later run sees what an earlier one wrote
    /// (closing and reopening the app). Read by scripts/snapshot.sh.
    public var library: String?
    /// Window content size; defaults to 1100×760.
    public var window: Size?
    public let steps: [ScenarioStep]

    public struct Size: Decodable, Sendable, Equatable {
        public let width: Double
        public let height: Double
    }

    public static func load(from url: URL) throws -> Scenario {
        try JSONDecoder().decode(Scenario.self, from: Data(contentsOf: url))
    }
}

/// One action or check in a scenario.
public enum ScenarioStep: Decodable, Sendable, Equatable {
    /// Left-clicks the named UI target.
    case click(String)
    /// Right-clicks the target and picks the context-menu item with this title.
    case contextMenu(target: String, item: String)
    /// Types text into whatever has keyboard focus.
    case type(String)
    /// Presses a named key, e.g. "return", "escape", or "]" with ["command"].
    case key(String, modifiers: [String])
    /// Clicks the button with this title in the alert or sheet on screen.
    case alertButton(String)
    /// Drops a book (found by title) on a slot, exactly as the slot's drop handler does.
    case dragBook(title: String, toShelf: String, slot: Int)
    /// Drops a shelf on another chest in the sidebar, as its drop handler does.
    case dragShelf(name: String, toChest: String)
    /// Resizes the window content.
    case resize(Scenario.Size)
    /// Waits for animations or autosave.
    case wait(seconds: Double)
    /// Writes `<name>.png`.
    case snapshot(String)
    /// Checks the app state; a failed check stops the scenario.
    case expect(ScenarioExpectation)

    private enum Key: String, CodingKey {
        case click, contextMenu, item, type, key, modifiers, alertButton
        case dragBook, toShelf, slot, dragShelf, toChest, resize, wait, snapshot, expect
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        if let target = try c.decodeIfPresent(String.self, forKey: .click) {
            self = .click(target)
        } else if let target = try c.decodeIfPresent(String.self, forKey: .contextMenu) {
            self = .contextMenu(target: target, item: try c.decode(String.self, forKey: .item))
        } else if let text = try c.decodeIfPresent(String.self, forKey: .type) {
            self = .type(text)
        } else if let key = try c.decodeIfPresent(String.self, forKey: .key) {
            self = .key(key, modifiers: try c.decodeIfPresent([String].self, forKey: .modifiers) ?? [])
        } else if let title = try c.decodeIfPresent(String.self, forKey: .alertButton) {
            self = .alertButton(title)
        } else if let title = try c.decodeIfPresent(String.self, forKey: .dragBook) {
            self = .dragBook(
                title: title,
                toShelf: try c.decode(String.self, forKey: .toShelf),
                slot: try c.decode(Int.self, forKey: .slot)
            )
        } else if let name = try c.decodeIfPresent(String.self, forKey: .dragShelf) {
            self = .dragShelf(name: name, toChest: try c.decode(String.self, forKey: .toChest))
        } else if let size = try c.decodeIfPresent(Scenario.Size.self, forKey: .resize) {
            self = .resize(size)
        } else if let seconds = try c.decodeIfPresent(Double.self, forKey: .wait) {
            self = .wait(seconds: seconds)
        } else if let name = try c.decodeIfPresent(String.self, forKey: .snapshot) {
            self = .snapshot(name)
        } else if let expectation = try c.decodeIfPresent(ScenarioExpectation.self, forKey: .expect) {
            self = .expect(expectation)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown scenario step \(c.allKeys.map(\.stringValue))")
            )
        }
    }
}

/// Things a scenario can assert about the running app. Every field is optional.
public struct ScenarioExpectation: Decodable, Sendable, Equatable {
    /// "chests", "chest" or "book".
    public var route: String?
    /// Exact chest names on the home screen, in order.
    public var chests: [String]?
    /// Exact shelf names in the open chest, in order.
    public var shelves: [String]?
    /// Per shelf, its books as "slot:title" in slot order.
    public var books: [String: [String]]?
    /// Text of the visible page.
    public var pageText: String?
    /// The "Page X of Y" label.
    public var pageLabel: String?
    /// Whether the open book is signed.
    public var signed: Bool?
    /// Whether a sheet or alert is showing.
    public var sheet: Bool?
    /// Whether the page text view has keyboard focus (ready to type).
    public var typingIntoPage: Bool?
    /// A file under the library root containing some text.
    public var file: FileExpectation?

    public struct FileExpectation: Decodable, Sendable, Equatable {
        /// Path relative to the library folder.
        public let path: String
        /// Text the file must contain.
        public let contains: String
    }
}
