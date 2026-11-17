import BookAssets
import SwiftUI

/// What an empty screen shows: a big icon, one line saying what belongs
/// here, and a button that makes the first one.
struct EmptyState: View {
    let texture: AssetCatalog.Texture
    let message: String
    let actionTitle: String
    let targetID: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            PixelTexture(texture: texture, scale: 6)
            PixelText(message, color: PixelTheme.text)
                .multilineTextAlignment(.center)
            PixelButton(title: actionTitle, width: 140, action: action)
                .uiTarget(targetID)
        }
        .padding(32)
        .background(Color.black.opacity(0.3))
    }
}
