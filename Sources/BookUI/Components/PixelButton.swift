import BookAssets
import SwiftUI

/// A Minecraft button: the 200×20 button texture drawn as a left and a right
/// half (exactly how the game draws narrower buttons), with a click sound.
struct PixelButton: View {
    let title: String
    /// Width in GUI pixels (at most 200, the texture width).
    var width: CGFloat = 98
    var scale: CGFloat = PixelTheme.guiScale
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.playSound) private var playSound

    var body: some View {
        Button {
            playSound(.click)
            action()
        } label: {
            ZStack {
                PixelButtonBackground(state: state, width: width, scale: scale)
                PixelText(title, scale: scale, color: textColor)
                    .lineLimit(1)
                    .padding(.horizontal, 4 * scale)
            }
            .frame(width: width * scale, height: PixelButtonBackground.height * scale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .accessibilityLabel(Text(title))
    }

    private var state: PixelButtonBackground.State {
        if !isEnabled { return .disabled }
        return isHovered ? .highlighted : .normal
    }

    private var textColor: Color {
        switch state {
        case .disabled: PixelTheme.textDisabled
        case .highlighted: PixelTheme.textHighlighted
        case .normal: PixelTheme.text
        }
    }
}

/// The button texture split into two halves so any width up to 200 keeps its borders.
struct PixelButtonBackground: View {
    enum State {
        case normal, highlighted, disabled
    }

    static let height: CGFloat = 20
    static let textureWidth: CGFloat = 200

    let state: State
    let width: CGFloat
    let scale: CGFloat

    var body: some View {
        let leftWidth = (width / 2).rounded(.down)
        let rightWidth = width - leftWidth
        HStack(spacing: 0) {
            PixelTexture(texture: texture, scale: scale, crop: CGRect(x: 0, y: 0, width: leftWidth, height: Self.height))
            PixelTexture(
                texture: texture,
                scale: scale,
                crop: CGRect(x: Self.textureWidth - rightWidth, y: 0, width: rightWidth, height: Self.height)
            )
        }
    }

    private var texture: AssetCatalog.Texture {
        switch state {
        case .normal: .button
        case .highlighted: .buttonHighlighted
        case .disabled: .buttonDisabled
        }
    }
}
