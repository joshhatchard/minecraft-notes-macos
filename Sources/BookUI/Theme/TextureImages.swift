import AppKit
import BookAssets

/// A loaded texture and its size in texels.
struct TextureImage {
    let image: NSImage
    /// Width and height in texels (source pixels).
    let pixelSize: CGSize
}

/// Loads textures from the asset catalogue once and keeps them for reuse.
@MainActor
enum TextureImages {
    private static var cache: [AssetCatalog.Texture: TextureImage] = [:]
    private static var tiles: [TileKey: NSImage] = [:]

    private struct TileKey: Hashable {
        let texture: AssetCatalog.Texture
        let scale: Int
    }

    /// The texture, or `nil` if the file is missing or unreadable.
    static func texture(_ texture: AssetCatalog.Texture) -> TextureImage? {
        if let cached = cache[texture] {
            return cached
        }
        guard let url = AssetCatalog.url(for: texture),
            let image = NSImage(contentsOf: url),
            let representation = image.representations.first
        else {
            return nil
        }
        let pixelSize = CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        image.size = pixelSize
        let loaded = TextureImage(image: image, pixelSize: pixelSize)
        cache[texture] = loaded
        return loaded
    }

    /// The texture pre-scaled by an integer factor with nearest-neighbour
    /// sampling, for use as a repeating tile.
    static func tile(_ texture: AssetCatalog.Texture, scale: Int) -> NSImage? {
        let key = TileKey(texture: texture, scale: scale)
        if let cached = tiles[key] {
            return cached
        }
        guard let source = self.texture(texture) else { return nil }
        let size = CGSize(width: source.pixelSize.width * CGFloat(scale), height: source.pixelSize.height * CGFloat(scale))
        let sourceImage = source.image
        let scaled = NSImage(size: size, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .none
            sourceImage.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
            return true
        }
        tiles[key] = scaled
        return scaled
    }
}
