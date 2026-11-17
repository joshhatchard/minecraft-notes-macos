import BookCore
import SwiftUI

/// Home screen: every chest (semester) as a chest you can open.
struct ChestListScreen: View {
    let app: AppModel
    @Bindable var model: ChestListViewModel

    @State private var prompt: NamePrompt?
    @State private var deletion: DeletionRequest?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ZStack {
            TiledBackground(texture: .darkOakPlanks)
            VStack(spacing: 20) {
                PixelText("Book and Quill", scale: 4, color: PixelTheme.title)
                    .padding(.top, 24)
                PixelText("Your chests", color: PixelTheme.textSecondary)
                if model.chests.isEmpty {
                    Spacer()
                    EmptyState(
                        texture: .chest,
                        message: "No chests yet. A chest holds one semester.",
                        actionTitle: "Make Your First Chest",
                        targetID: UITargetID.firstChestButton,
                        action: promptNewChest
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(model.chests) { chest in
                                ChestTile(name: chest.name, detail: shelfCountText(chest.shelfCount)) {
                                    app.openChest(chest.id)
                                }
                                .contextMenu { contextMenu(for: chest) }
                                .uiTarget(UITargetID.chest(chest.name))
                            }
                        }
                        .padding(24)
                    }
                }
                HStack(spacing: 8) {
                    PixelButton(title: "New Chest", width: 98) { promptNewChest() }
                        .keyboardShortcut("n", modifiers: .command)
                        .uiTarget(UITargetID.newChestButton)
                    SettingsLink {
                        PixelButtonLabel(title: "Settings", width: 98)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
        }
        .sheet(item: $prompt) { NamePromptSheet(prompt: $0) }
        .deletionConfirmation($deletion)
        .errorAlert($model.errorMessage)
    }

    @ViewBuilder
    private func contextMenu(for chest: ChestSummary) -> some View {
        Button("Open") { app.openChest(chest.id) }
        Button("Rename…") {
            prompt = NamePrompt(
                title: "Rename Chest",
                initialName: chest.name,
                confirmTitle: "Rename",
                maxLength: BookLimits.maxContainerNameLength
            ) { name in
                model.renameChest(chest.id, to: name) ? nil : model.takeErrorMessage()
            }
        }
        Divider()
        Button("Delete…", role: .destructive) {
            deletion = DeletionRequest(
                title: "Delete the chest “\(chest.name)”?",
                message: "Its \(shelfCountText(chest.shelfCount)) and every book on them will be moved to the Trash."
            ) {
                model.deleteChest(chest.id)
            }
        }
    }

    private func promptNewChest() {
        prompt = NamePrompt(
            title: "New Chest (Semester)",
            confirmTitle: "Create",
            maxLength: BookLimits.maxContainerNameLength
        ) { name in
            model.createChest(named: name) ? nil : model.takeErrorMessage()
        }
    }

    private func shelfCountText(_ count: Int) -> String {
        count == 1 ? "1 shelf" : "\(count) shelves"
    }
}

/// A chest icon with its name, highlighted on hover.
struct ChestTile: View {
    let name: String
    let detail: String
    let open: () -> Void

    @State private var isHovered = false
    @Environment(\.playSound) private var playSound

    var body: some View {
        Button(action: open) {
            VStack(spacing: 8) {
                PixelTexture(texture: .chest, scale: PixelTheme.chestScale)
                    .overlay { if isHovered { PixelTheme.hoverHighlight } }
                PixelText(name, color: isHovered ? PixelTheme.textHighlighted : PixelTheme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                PixelText(detail, color: PixelTheme.textSecondary)
            }
            .frame(width: 150)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text("Chest \(name), \(detail)"))
    }
}

/// A button-textured label for controls that are not plain buttons (e.g. `SettingsLink`).
struct PixelButtonLabel: View {
    let title: String
    var width: CGFloat = 98
    var scale: CGFloat = PixelTheme.guiScale

    @State private var isHovered = false

    var body: some View {
        ZStack {
            PixelButtonBackground(state: isHovered ? .highlighted : .normal, width: width, scale: scale)
            PixelText(title, scale: scale, color: isHovered ? PixelTheme.textHighlighted : PixelTheme.text)
        }
        .frame(width: width * scale, height: PixelButtonBackground.height * scale)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
