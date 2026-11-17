import SwiftUI

/// Text in the pixel font with Minecraft's one-pixel drop shadow.
struct PixelText: View {
    let text: String
    var scale: CGFloat = PixelTheme.guiScale
    var color: Color = PixelTheme.text
    var shadow = true

    init(_ text: String, scale: CGFloat = PixelTheme.guiScale, color: Color = PixelTheme.text, shadow: Bool = true) {
        self.text = text
        self.scale = scale
        self.color = color
        self.shadow = shadow
    }

    var body: some View {
        Text(verbatim: text)
            .font(PixelTheme.font(scale: scale))
            .foregroundStyle(color)
            .background(alignment: .topLeading) {
                if shadow {
                    Text(verbatim: text)
                        .font(PixelTheme.font(scale: scale))
                        .foregroundStyle(PixelTheme.shadowColor(for: color))
                        .offset(x: scale, y: scale)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A Minecraft-style tooltip box: dark purple fill with a gradient border.
struct PixelTooltip<Content: View>: View {
    var scale: CGFloat = PixelTheme.guiScale
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: scale * 2) {
            content
        }
        .padding(.horizontal, 4 * scale)
        .padding(.vertical, 4 * scale)
        .background(PixelTheme.tooltipBackground)
        .overlay {
            Rectangle()
                .strokeBorder(
                    LinearGradient(
                        colors: [PixelTheme.tooltipBorderTop, PixelTheme.tooltipBorderBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: scale
                )
                .padding(scale)
        }
    }
}
