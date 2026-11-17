import SwiftUI

/// Colours, sizes and scale factors of the Minecraft-style interface.
///
/// Every size is expressed in GUI pixels (one texel of the 16×16 textures) and
/// multiplied by an integer scale, so pixel art stays crisp.
public enum PixelTheme {
    /// Integer scale for general interface chrome (buttons, labels).
    public static let guiScale: CGFloat = 2
    /// Integer scale for chiseled bookshelf blocks.
    public static let shelfScale: CGFloat = 6
    /// Integer scale for chest icons on the home screen.
    public static let chestScale: CGFloat = 5

    /// Font size in GUI pixels (the bundled font is designed at 8 pt).
    public static let fontSize: CGFloat = 8
    /// Line advance in GUI pixels, as in Minecraft's book.
    public static let lineHeight: CGFloat = 9

    /// Ink used for page text.
    public static let ink = Color.black
    /// Page number and secondary page text.
    public static let pageNumberInk = Color.black
    /// Normal button and label text.
    public static let text = Color(red: 0xE0 / 255, green: 0xE0 / 255, blue: 0xE0 / 255)
    /// Hovered button text.
    public static let textHighlighted = Color(red: 1, green: 1, blue: 0xA0 / 255)
    /// Disabled button text.
    public static let textDisabled = Color(red: 0xA0 / 255, green: 0xA0 / 255, blue: 0xA0 / 255)
    /// Secondary label text.
    public static let textSecondary = Color(red: 0xAA / 255, green: 0xAA / 255, blue: 0xAA / 255)
    /// Title text.
    public static let title = Color.white
    /// Highlight drawn over drop targets.
    public static let dropHighlight = Color(red: 1, green: 0.85, blue: 0.3).opacity(0.35)
    /// Highlight drawn over hovered slots.
    public static let hoverHighlight = Color.white.opacity(0.18)
    /// Background of Minecraft-style tooltips.
    public static let tooltipBackground = Color(red: 0x10 / 255, green: 0, blue: 0x10 / 255).opacity(0.94)
    /// Tooltip border, top.
    public static let tooltipBorderTop = Color(red: 0x50 / 255, green: 0, blue: 1).opacity(0.31)
    /// Tooltip border, bottom.
    public static let tooltipBorderBottom = Color(red: 0x28 / 255, green: 0, blue: 0x7F / 255).opacity(0.31)
    /// Dark overlay over tiled backgrounds so text stays readable.
    public static let backgroundDim = Color.black.opacity(0.45)
    /// Fill of text input boxes.
    public static let fieldFill = Color.black
    /// Border of text input boxes.
    public static let fieldBorder = Color(red: 0xA0 / 255, green: 0xA0 / 255, blue: 0xA0 / 255)

    /// The pixel font at `scale` (8 pt × scale).
    public static func font(scale: CGFloat) -> Font {
        .custom(FontRegistry.pixelFontName, fixedSize: fontSize * scale)
    }

    /// Minecraft's text shadow: the text colour at a quarter brightness, offset one pixel.
    public static func shadowColor(for color: Color) -> Color {
        let resolved = color.resolve(in: EnvironmentValues())
        return Color(
            red: Double(resolved.red) / 4,
            green: Double(resolved.green) / 4,
            blue: Double(resolved.blue) / 4,
            opacity: Double(resolved.opacity)
        )
    }
}
