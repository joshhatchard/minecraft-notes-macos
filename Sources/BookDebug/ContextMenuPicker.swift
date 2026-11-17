import AppKit

/// Picks an item from a view's real context menu by title.
///
/// The menu comes from the same `menu(for:)` call AppKit makes for a right
/// click, so it holds exactly what SwiftUI's `.contextMenu` declared. It is
/// not shown on screen: a modal menu-tracking loop only starts reliably in an
/// active app, and a scenario run over SSH launches in the background.
@MainActor
enum ContextMenuPicker {
    static func pick(_ title: String, rightClicking point: CGPoint, in window: NSWindow) throws {
        guard let root = window.contentView?.superview ?? window.contentView else {
            throw ScenarioFailure("window has no content view")
        }
        let location = EventSynthesizer.windowLocation(of: point, in: window)
        guard
            let event = NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: location,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        else { throw ScenarioFailure("could not create a right-click event") }

        guard let menu = contextMenu(at: root.convert(location, from: nil), for: event, in: root) else {
            throw ScenarioFailure("right-click opened no context menu")
        }
        guard let index = menu.items.firstIndex(where: { $0.title == title && $0.isEnabled }) else {
            let available = menu.items.map(\.title).filter { !$0.isEmpty }
            throw ScenarioFailure("context menu has no item \"\(title)\" (has: \(available.joined(separator: ", ")))")
        }
        menu.performActionForItem(at: index)
    }

    /// Walks from the deepest view under `point` towards the root, the way a
    /// right click does, and returns the first menu a view offers.
    private static func contextMenu(at point: NSPoint, for event: NSEvent, in root: NSView) -> NSMenu? {
        var view = root.hitTest(point)
        while let current = view {
            if let menu = current.menu(for: event) { return menu }
            view = current.superview
        }
        return nil
    }
}
