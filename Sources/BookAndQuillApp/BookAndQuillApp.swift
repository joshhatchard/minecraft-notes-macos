import BookUI
import SwiftUI

@main
struct BookAndQuillApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup("Book and Quill") {
            RootView(app: appDelegate.composition.app, targets: appDelegate.composition.debug?.targets)
        }
        .defaultSize(width: 1100, height: 760)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                appDelegate.composition.app.flushPendingChanges()
            }
        }

        Settings {
            SettingsView(app: appDelegate.composition.app)
        }
    }
}
