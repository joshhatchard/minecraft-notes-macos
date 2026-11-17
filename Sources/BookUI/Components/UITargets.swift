import SwiftUI

/// Where named, clickable parts of the interface are on screen.
///
/// Only used by the debug scenario runner (BookDebug), which clicks these
/// places with synthesized mouse events, so clicks go through SwiftUI's real
/// hit testing. In the normal app no registry is installed and
/// ``SwiftUI/View/uiTarget(_:)`` does nothing.
@MainActor
public final class UITargetRegistry {
    /// A recorded target.
    public struct Target: Equatable, Sendable {
        /// Frame in its window's content coordinate space (origin top-left).
        public let frame: CGRect
        /// Whether it is drawn in a sheet rather than the main window.
        public let inSheet: Bool
    }

    private var targets: [String: Target] = [:]

    public init() {}

    /// A target, if it is currently on screen.
    public func target(_ id: String) -> Target? {
        targets[id]
    }

    /// Every target id currently on screen, sorted (for error messages).
    public var knownIDs: [String] {
        targets.keys.sorted()
    }

    func update(_ id: String, target: Target?) {
        targets[id] = target
    }
}

extension EnvironmentValues {
    /// Registry that records target frames; `nil` (off) in the normal app.
    @Entry public var uiTargetRegistry: UITargetRegistry?
    /// Set by sheets so their targets are looked up in the sheet window.
    @Entry var uiTargetInSheet = false
}

/// Stable target names, shared by the views and the scenario files.
public enum UITargetID {
    public static let newChestButton = "new-chest"
    public static let newShelfButton = "new-shelf"
    public static let firstChestButton = "first-chest"
    public static let firstShelfButton = "first-shelf"
    public static let backButton = "back"
    public static let promptField = "prompt-field"
    public static let promptConfirm = "prompt-confirm"
    public static let promptCancel = "prompt-cancel"
    public static let pageText = "page-text"
    public static let pageForward = "page-forward"
    public static let pageBackward = "page-backward"
    public static let signButton = "sign"
    public static let doneButton = "done"
    public static let signConfirm = "sign-confirm"
    public static let signCancel = "sign-cancel"
    public static let signTitleField = "sign-title"
    public static let signAuthorField = "sign-author"

    public static func chest(_ name: String) -> String { "chest:\(name)" }
    public static func shelf(_ name: String) -> String { "shelf:\(name)" }
    public static func newBook(onShelf name: String) -> String { "new-book:\(name)" }
    public static func bookTitle(_ title: String, onShelf name: String) -> String { "book:\(name):\(title)" }
    public static func slot(_ slot: Int, onShelf name: String) -> String { "slot:\(name):\(slot)" }
}

private struct UITargetModifier: ViewModifier {
    let id: String
    @Environment(\.uiTargetRegistry) private var registry
    @Environment(\.uiTargetInSheet) private var inSheet

    func body(content: Content) -> some View {
        if let registry {
            content
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    registry.update(id, target: .init(frame: frame, inSheet: inSheet))
                }
                .onDisappear { registry.update(id, target: nil) }
        } else {
            content
        }
    }
}

extension View {
    /// Names this view so the debug scenario runner can click it.
    public func uiTarget(_ id: String) -> some View {
        modifier(UITargetModifier(id: id))
    }
}
