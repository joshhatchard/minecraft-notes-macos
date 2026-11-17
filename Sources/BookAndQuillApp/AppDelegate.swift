import AppKit

/// Owns the composition root and makes sure edits reach the disk on quit.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let composition = AppComposition()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run`) rather than an .app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        composition.app.flushPendingChanges()
    }

    func applicationDidResignActive(_ notification: Notification) {
        composition.app.flushPendingChanges()
    }
}
