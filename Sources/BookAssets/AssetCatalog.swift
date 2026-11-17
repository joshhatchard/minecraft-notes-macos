import Foundation

/// The single entry point to every texture, font and sound file.
///
/// All files live in `Sources/BookAssets/Assets`. To reskin the app, replace
/// files there keeping these names; nothing else needs to change.
public enum AssetCatalog {
    /// Pixel-art textures (PNG, 1 texel = 1 GUI pixel).
    public enum Texture: String, CaseIterable, Sendable {
        case book
        case pageForward = "page_forward"
        case pageForwardHighlighted = "page_forward_highlighted"
        case pageBackward = "page_backward"
        case pageBackwardHighlighted = "page_backward_highlighted"
        case button
        case buttonHighlighted = "button_highlighted"
        case buttonDisabled = "button_disabled"
        case chiseledBookshelfEmpty = "chiseled_bookshelf_empty"
        case chiseledBookshelfOccupied = "chiseled_bookshelf_occupied"
        case darkOakPlanks = "dark_oak_planks"
        case oakPlanks = "oak_planks"
        case bookshelf
        case bookAndQuill = "book_and_quil"
        case chest
    }

    /// Bundled fonts.
    public enum FontFile: String, CaseIterable, Sendable {
        case minecraft = "minecraft_local_v2"

        /// The PostScript name to request the font by once registered.
        public var postScriptName: String {
            switch self {
            case .minecraft: "MinecraftLocalV2"
            }
        }
    }

    /// Sound effect files (WAV).
    public enum SoundFile: String, CaseIterable, Sendable {
        case click
        case insert
        case pickup
        case pageTurn1 = "page_turn1"
        case pageTurn2 = "page_turn2"
        case pageTurn3 = "page_turn3"
    }

    /// URL of a texture file, or `nil` if it is missing from the bundle.
    public static func url(for texture: Texture) -> URL? {
        resource(texture.rawValue, extension: "png", folder: "textures")
    }

    /// URL of a font file, or `nil` if it is missing from the bundle.
    public static func url(for font: FontFile) -> URL? {
        resource(font.rawValue, extension: "ttf", folder: "fonts")
    }

    /// URL of a sound file, or `nil` if it is missing from the bundle.
    public static func url(for sound: SoundFile) -> URL? {
        resource(sound.rawValue, extension: "wav", folder: "sounds")
    }

    private static func resource(_ name: String, extension fileExtension: String, folder: String) -> URL? {
        guard let base = resourceBundle.resourceURL else { return nil }
        let url = base
            .appending(path: "Assets", directoryHint: .isDirectory)
            .appending(path: folder, directoryHint: .isDirectory)
            .appending(path: "\(name).\(fileExtension)", directoryHint: .notDirectory)
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// The resource bundle. Inside a packaged `.app` it lives in
    /// `Contents/Resources` (where code signing expects it); during `swift run`
    /// and `swift test` SwiftPM's generated accessor finds it next to the binary.
    private static let resourceBundle: Bundle = {
        let bundleName = "BookAndQuill_BookAssets.bundle"
        if let packaged = Bundle.main.resourceURL?.appending(path: bundleName),
           let bundle = Bundle(url: packaged) {
            return bundle
        }
        return Bundle.module
    }()
}
