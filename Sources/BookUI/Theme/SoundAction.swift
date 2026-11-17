import BookAudio
import SwiftUI

/// Plays a sound effect from a view (button clicks). Injected through the
/// environment by the app root so views never own a sound player.
public struct SoundAction: Sendable {
    private let handler: @MainActor @Sendable (SoundEffect) -> Void

    public init(_ handler: @escaping @MainActor @Sendable (SoundEffect) -> Void) {
        self.handler = handler
    }

    @MainActor
    public func callAsFunction(_ effect: SoundEffect) {
        handler(effect)
    }
}

extension EnvironmentValues {
    /// Plays interface sound effects. Silent unless the app root provides one.
    @Entry public var playSound = SoundAction { _ in }
}
