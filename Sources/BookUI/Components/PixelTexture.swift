import BookAssets
import SwiftUI

/// Draws a texture (or a rectangular crop of it) at an integer scale with
/// nearest-neighbour sampling.
struct PixelTexture: View {
    let texture: AssetCatalog.Texture
    let scale: CGFloat
    /// Crop rectangle in texels; `nil` draws the whole texture.
    var crop: CGRect?
    /// Mirror horizontally.
    var flipped = false

    var body: some View {
        if let loaded = TextureImages.texture(texture) {
            let region = crop ?? CGRect(origin: .zero, size: loaded.pixelSize)
            Image(nsImage: loaded.image)
                .interpolation(.none)
                .resizable()
                .frame(width: loaded.pixelSize.width * scale, height: loaded.pixelSize.height * scale)
                .offset(x: -region.minX * scale, y: -region.minY * scale)
                .frame(width: region.width * scale, height: region.height * scale, alignment: .topLeading)
                .clipped()
                .scaleEffect(x: flipped ? -1 : 1, y: 1)
                .accessibilityHidden(true)
        } else {
            // A visible but quiet stand-in if an asset is missing after a reskin.
            Rectangle()
                .fill(Color(red: 0.35, green: 0.2, blue: 0.35))
                .frame(width: (crop?.width ?? 16) * scale, height: (crop?.height ?? 16) * scale)
        }
    }
}

/// Fills its space with a repeating texture, scaled by an integer factor.
struct TiledBackground: View {
    let texture: AssetCatalog.Texture
    var scale = 4
    var dim = true

    var body: some View {
        ZStack {
            if let tile = TextureImages.tile(texture, scale: scale) {
                Image(nsImage: tile)
                    .resizable(resizingMode: .tile)
            } else {
                Color(red: 0.2, green: 0.13, blue: 0.08)
            }
            if dim {
                PixelTheme.backgroundDim
            }
        }
        .ignoresSafeArea()
    }
}
