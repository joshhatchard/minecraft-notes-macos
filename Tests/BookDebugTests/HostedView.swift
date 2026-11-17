import AppKit
import SwiftUI

@testable import BookDebug
@testable import BookUI

/// Hosts a SwiftUI view in a real window so tests can click it with
/// synthesized events and exercise SwiftUI's actual hit testing.
@MainActor
final class HostedView {
    let window: NSWindow
    let targets = UITargetRegistry()

    init(size: CGSize = CGSize(width: 600, height: 400), @ViewBuilder content: () -> some View) {
        _ = NSApplication.shared
        window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: 80, y: 80), size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content().environment(\.uiTargetRegistry, targets))
        window.makeKeyAndOrderFront(nil)
        settle()
    }

    /// Lets SwiftUI lay out and run pending updates.
    func settle(_ seconds: TimeInterval = 0.3) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// Clicks the centre of a named target. Returns `false` if it is not on screen.
    @discardableResult
    func click(_ id: String) -> Bool {
        guard let target = targets.target(id) else { return false }
        EventSynthesizer.click(at: CGPoint(x: target.frame.midX, y: target.frame.midY), in: window)
        settle()
        return true
    }

    /// Hides the window. (`close()` on the last window of an app that never
    /// finished launching ends the test process.)
    func close() {
        window.orderOut(nil)
        window.contentView = nil
    }
}

