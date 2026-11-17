import AppKit

/// Opens a view's real context menu with a synthesized right click and picks
/// an item from it by title.
///
/// The right click starts AppKit's modal menu-tracking loop, so the item is
/// chosen from inside that loop once the menu reports it began tracking.
@MainActor
final class ContextMenuPicker: NSObject {
    private let title: String
    private var menu: NSMenu?
    private var chosenIndex: Int?
    private var available: [String] = []

    private init(title: String) {
        self.title = title
    }

    static func pick(_ title: String, rightClicking point: CGPoint, in window: NSWindow) throws {
        let picker = ContextMenuPicker(title: title)
        NotificationCenter.default.addObserver(
            picker,
            selector: #selector(menuDidBeginTracking(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        defer { NotificationCenter.default.removeObserver(picker) }

        EventSynthesizer.click(at: point, in: window, button: .right)
        try picker.performChoice()
    }

    @objc private func menuDidBeginTracking(_ note: Notification) {
        menu = note.object as? NSMenu
        // Choose once the menu is on screen, inside its tracking run loop mode.
        RunLoop.main.perform(inModes: [.eventTracking, .common]) { [self] in
            MainActor.assumeIsolated { chooseAndClose() }
        }
    }

    private func chooseAndClose() {
        guard let menu else { return }
        available = menu.items.map(\.title)
        chosenIndex = menu.items.firstIndex { $0.title == title && $0.isEnabled }
        menu.cancelTracking()
    }

    private func performChoice() throws {
        guard let menu, let chosenIndex else {
            throw ScenarioFailure(
                available.isEmpty
                    ? "right-click opened no context menu"
                    : "context menu has no item \"\(title)\" (has: \(available.joined(separator: ", ")))"
            )
        }
        menu.performActionForItem(at: chosenIndex)
    }
}
