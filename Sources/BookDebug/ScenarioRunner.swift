import AppKit
import BookCore
import BookUI

/// Plays a ``Scenario`` against the running app and photographs it.
///
/// Clicks and key presses are synthesized events (see ``EventSynthesizer``),
/// so they go through the same hit testing and handlers as a real mouse.
/// Drag and drop is the exception: AppKit drag sessions need the real window
/// server, so drag steps hand the drag payload to the same drop handlers the
/// slots and chests call.
@MainActor
public final class ScenarioRunner {
    /// Pause after each step so SwiftUI updates and short animations finish.
    static let settleTime: Duration = .milliseconds(450)

    private let app: AppModel
    private let targets: UITargetRegistry
    private let libraryRoot: URL
    private let output: URL
    private let log: DebugLog
    private var snapshotCount = 0

    public init(app: AppModel, targets: UITargetRegistry, libraryRoot: URL, output: URL, log: DebugLog) {
        self.app = app
        self.targets = targets
        self.libraryRoot = libraryRoot
        self.output = output
        self.log = log
    }

    /// Runs every step. Returns `nil` on success, or what went wrong.
    public func run(_ scenario: Scenario) async -> String? {
        log.write("scenario \(scenario.name): \(scenario.steps.count) steps")
        guard let window = await waitForWindow() else { return SnapshotError.noWindow.description }
        let size = scenario.window ?? Scenario.Size(width: 1100, height: 760)
        resize(window, to: size)
        try? await Task.sleep(for: Self.settleTime)
        log.write("app active: \(NSApp.isActive), window key: \(window.isKeyWindow)")

        for (index, step) in scenario.steps.enumerated() {
            log.write("step \(index + 1): \(step)")
            do {
                try await perform(step, in: window)
            } catch {
                let message = "step \(index + 1) (\(step)) failed: \(error)"
                log.write("FAIL \(message)")
                snapshot("FAILED", in: window)
                return message
            }
            try? await Task.sleep(for: Self.settleTime)
        }
        log.write("PASS")
        return nil
    }

    // MARK: Steps

    private func perform(_ step: ScenarioStep, in window: NSWindow) async throws {
        switch step {
        case .click(let id):
            let (target, targetWindow) = try locate(id, in: window)
            EventSynthesizer.click(at: CGPoint(x: target.frame.midX, y: target.frame.midY), in: targetWindow)
        case .contextMenu(let id, let item):
            let (target, targetWindow) = try locate(id, in: window)
            try ContextMenuPicker.pick(item, rightClicking: CGPoint(x: target.frame.midX, y: target.frame.midY), in: targetWindow)
        case .type(let text):
            EventSynthesizer.type(text, in: NSApp.keyWindow ?? window.attachedSheet ?? window)
        case .key(let name, let modifiers):
            guard let key = EventSynthesizer.Key.named[name] else { throw ScenarioFailure("unknown key \(name)") }
            if !modifiers.isEmpty, !window.isKeyWindow {
                // Seen over SSH: macOS will not activate an app launched in the
                // background, and SwiftUI's .keyboardShortcut only fires in the
                // key window. Menu key equivalents (⌘A) still work.
                log.write("warning: window is not key, so SwiftUI button shortcuts will not fire")
            }
            EventSynthesizer.press(key, modifiers: try modifierFlags(modifiers), in: NSApp.keyWindow ?? window)
        case .alertButton(let title):
            try clickAlertButton(title, over: window)
        case .dragBook(let title, let shelfName, let slot):
            try dropBook(title: title, onShelf: shelfName, slot: slot)
        case .dragShelf(let name, let chestName):
            try dropShelf(name, onChest: chestName)
        case .resize(let size):
            resize(window, to: size)
        case .wait(let seconds):
            try? await Task.sleep(for: .seconds(seconds))
        case .snapshot(let name):
            snapshot(name, in: window)
        case .expect(let expectation):
            let problems = ExpectationChecker(app: app, window: window, libraryRoot: libraryRoot).problems(with: expectation)
            if !problems.isEmpty { throw ScenarioFailure(problems.joined(separator: "; ")) }
        }
    }

    private func locate(_ id: String, in window: NSWindow) throws -> (UITargetRegistry.Target, NSWindow) {
        guard let target = targets.target(id) else {
            throw ScenarioFailure("no target \"\(id)\" on screen. Visible: \(targets.knownIDs.joined(separator: ", "))")
        }
        if target.inSheet {
            guard let sheet = window.attachedSheet else { throw ScenarioFailure("\"\(id)\" is in a sheet, but none is open") }
            return (target, sheet)
        }
        return (target, window)
    }

    private func clickAlertButton(_ title: String, over window: NSWindow) throws {
        let candidates = [window.attachedSheet].compactMap { $0 } + NSApp.windows.filter { $0.isVisible && $0 !== window }
        for candidate in candidates {
            if let button = Self.button(titled: title, in: candidate.contentView) {
                button.performClick(nil)
                return
            }
        }
        throw ScenarioFailure("no alert button \"\(title)\"")
    }

    private static func button(titled title: String, in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton, button.title == title, button.isEnabled { return button }
        for subview in view.subviews {
            if let found = button(titled: title, in: subview) { return found }
        }
        return nil
    }

    private func dropBook(title: String, onShelf shelfName: String, slot: Int) throws {
        guard let chest = app.chest else { throw ScenarioFailure("no chest is open") }
        guard let book = chest.shelves.lazy.flatMap(\.books).first(where: { $0.title == title }) else {
            throw ScenarioFailure("no book titled \"\(title)\"")
        }
        guard let shelf = chest.shelves.first(where: { $0.name == shelfName }) else {
            throw ScenarioFailure("no shelf \"\(shelfName)\"")
        }
        guard chest.handleDrop([DragPayload.book(book.id).encoded], onSlot: slot, of: shelf.id) else {
            throw ScenarioFailure("the slot refused the book")
        }
    }

    private func dropShelf(_ name: String, onChest chestName: String) throws {
        guard let chest = app.chest else { throw ScenarioFailure("no chest is open") }
        guard let shelf = chest.shelves.first(where: { $0.name == name }) else { throw ScenarioFailure("no shelf \"\(name)\"") }
        guard let target = chest.otherChests.first(where: { $0.name == chestName }) else {
            throw ScenarioFailure("no other chest \"\(chestName)\" in the sidebar")
        }
        guard chest.handleDrop([DragPayload.shelf(shelf.id).encoded], onChest: target.id) else {
            throw ScenarioFailure("the chest refused the shelf")
        }
    }

    // MARK: Helpers

    /// Writes the next numbered snapshot, e.g. `03-book-open.png`.
    public func snapshot(_ name: String, in window: NSWindow) {
        snapshotCount += 1
        let file = output.appending(path: String(format: "%02d-%@.png", snapshotCount, name))
        do {
            try WindowSnapshotter.writePNG(of: window, to: file)
            log.write("snapshot \(file.lastPathComponent)")
        } catch {
            log.write("snapshot \(name) failed: \(error)")
        }
    }

    private func waitForWindow() async -> NSWindow? {
        for _ in 0..<100 {
            if let window = WindowSnapshotter.mainWindow, !targets.knownIDs.isEmpty {
                window.makeKeyAndOrderFront(nil)
                return window
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private func resize(_ window: NSWindow, to size: Scenario.Size) {
        window.setContentSize(NSSize(width: size.width, height: size.height))
    }

    private func modifierFlags(_ names: [String]) throws -> NSEvent.ModifierFlags {
        try names.reduce(into: []) { flags, name in
            switch name {
            case "command": flags.insert(.command)
            case "shift": flags.insert(.shift)
            case "option": flags.insert(.option)
            case "control": flags.insert(.control)
            default: throw ScenarioFailure("unknown modifier \(name)")
            }
        }
    }
}

/// A scenario step that could not be carried out.
struct ScenarioFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
