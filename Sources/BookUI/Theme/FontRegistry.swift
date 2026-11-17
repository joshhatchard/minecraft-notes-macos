import AppKit
import BookAssets
import CoreText

/// Registers the bundled pixel font with the process so SwiftUI and AppKit can use it by name.
@MainActor
public enum FontRegistry {
    /// PostScript name of the page and interface font.
    public nonisolated static let pixelFontName = AssetCatalog.FontFile.minecraft.postScriptName

    private static var registered = false

    /// Registers every bundled font once. Safe to call repeatedly.
    public static func registerBundledFonts() {
        guard !registered else { return }
        registered = true
        for font in AssetCatalog.FontFile.allCases {
            guard let url = AssetCatalog.url(for: font) else { continue }
            // Fails harmlessly if the font is already registered.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// The pixel font at `size` points, falling back to a monospaced system
    /// font if the bundled font is missing.
    public static func pixelFont(size: CGFloat) -> NSFont {
        registerBundledFonts()
        return NSFont(name: pixelFontName, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
