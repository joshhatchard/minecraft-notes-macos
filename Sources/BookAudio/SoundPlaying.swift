/// The sound effects the app plays. There is no music.
public enum SoundEffect: CaseIterable, Sendable {
    /// Turning a page in the book editor.
    case pageTurn
    /// Pressing a button.
    case click
    /// Opening a chest.
    case chestOpen
    /// Taking a book off a shelf to read it.
    case bookOpen
    /// Placing a book (or shelf) somewhere after a drag.
    case bookPlace
}

/// Plays sound effects. Injected into view models so tests can stay silent.
@MainActor
public protocol SoundPlaying: AnyObject {
    /// Plays `effect` once, without blocking.
    func play(_ effect: SoundEffect)
}

/// A ``SoundPlaying`` that does nothing, for tests and previews.
@MainActor
public final class SilentSoundPlayer: SoundPlaying {
    public init() {}

    public func play(_ effect: SoundEffect) {}
}
