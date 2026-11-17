import AVFoundation
import BookAssets

/// Plays the bundled WAV files through AVFoundation.
///
/// Players are created lazily and reused; a sound that is still playing is
/// restarted rather than stacked, which keeps rapid page turns crisp.
@MainActor
public final class AudioFileSoundPlayer: SoundPlaying {
    private var players: [AssetCatalog.SoundFile: AVAudioPlayer] = [:]
    private let volume: Float

    /// - Parameter volume: Linear volume from 0 to 1 applied to every effect.
    public init(volume: Float = 0.6) {
        self.volume = volume
    }

    public func play(_ effect: SoundEffect) {
        guard let file = effect.files.randomElement(), let player = player(for: file) else { return }
        player.currentTime = 0
        player.play()
    }

    private func player(for file: AssetCatalog.SoundFile) -> AVAudioPlayer? {
        if let cached = players[file] {
            return cached
        }
        guard let url = AssetCatalog.url(for: file), let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        player.volume = volume
        player.prepareToPlay()
        players[file] = player
        return player
    }
}
