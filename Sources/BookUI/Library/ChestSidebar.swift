import BookCore
import SwiftUI

/// The other chests, listed as drop targets for moving a shelf between chests.
struct ChestSidebar: View {
    let chests: [ChestSummary]
    let drop: ([String], ChestID) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelText("Other chests", color: PixelTheme.textSecondary)
            if chests.isEmpty {
                PixelText("None yet", color: PixelTheme.textSecondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(chests) { chest in
                        ChestDropTarget(chest: chest, drop: drop)
                    }
                }
            }
            PixelText("Drag a shelf's name onto a chest to move it there.", scale: 1, color: PixelTheme.textSecondary)
        }
        .padding(12)
        .frame(width: 190, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.3))
    }
}

private struct ChestDropTarget: View {
    let chest: ChestSummary
    let drop: ([String], ChestID) -> Bool

    @State private var isTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            PixelTexture(texture: .chest, scale: PixelTheme.guiScale)
            PixelText(chest.name, color: isTargeted ? PixelTheme.textHighlighted : PixelTheme.text)
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isTargeted ? PixelTheme.dropHighlight : .clear)
        .dropDestination(for: String.self) { items, _ in
            drop(items, chest.id)
        } isTargeted: {
            isTargeted = $0
        }
        .accessibilityLabel(Text("Chest \(chest.name), drop a shelf here"))
    }
}
