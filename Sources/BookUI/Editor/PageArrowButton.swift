import BookAssets
import SwiftUI

/// The book's page_forward / page_backward arrow, highlighted on hover.
struct PageArrowButton: View {
    enum Direction {
        case forward, backward
    }

    let direction: Direction
    let scale: CGFloat
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            PixelTexture(texture: texture, scale: scale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
        .accessibilityLabel(Text(help))
    }

    private var texture: AssetCatalog.Texture {
        switch (direction, isHovered) {
        case (.forward, false): .pageForward
        case (.forward, true): .pageForwardHighlighted
        case (.backward, false): .pageBackward
        case (.backward, true): .pageBackwardHighlighted
        }
    }
}
