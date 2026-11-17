import AppKit
import SwiftUI

/// Preferences window: library folder and default author.
public struct SettingsView: View {
    @Bindable private var app: AppModel

    public init(app: AppModel) {
        self.app = app
    }

    public var body: some View {
        Form {
            Section("Library folder") {
                Text(app.libraryRoot.path(percentEncoded: false))
                    .textSelection(.enabled)
                    .lineLimit(2)
                HStack {
                    Button("Choose…", action: chooseFolder)
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.libraryRoot])
                    }
                }
                Text("Chests, shelves and books are plain folders and text files here. Put it in iCloud Drive to sync.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Signing") {
                TextField("Author name", text: $app.authorName)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = app.libraryRoot
        panel.prompt = "Use Folder"
        if panel.runModal() == .OK, let url = panel.url {
            app.changeLibraryRoot(to: url)
        }
    }
}
