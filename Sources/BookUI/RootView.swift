import SwiftUI

/// Shows the screen for the current route.
public struct RootView: View {
    private let app: AppModel

    public init(app: AppModel) {
        self.app = app
        FontRegistry.registerBundledFonts()
    }

    public var body: some View {
        Group {
            switch app.route {
            case .chests:
                ChestListScreen(app: app, model: app.chestList)
            case .chest:
                if let chest = app.chest {
                    ChestScreen(app: app, model: chest)
                }
            case .book:
                if let editor = app.editor {
                    BookEditorScreen(app: app, model: editor)
                }
            }
        }
        .environment(\.playSound, SoundAction { [app] effect in app.play(effect) })
        .frame(minWidth: 820, minHeight: 600)
    }
}
