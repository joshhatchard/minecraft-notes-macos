import BookAudio
import BookCore
import BookDebug
import BookStorage
import BookUI
import Foundation

/// Dependency wiring: the one place concrete implementations are chosen.
@MainActor
final class AppComposition {
    let app: AppModel
    /// Debug facilities requested on the command line; `nil` in normal use.
    let debug: DebugSession?

    init(arguments: [String] = CommandLine.arguments) {
        FontRegistry.registerBundledFonts()
        let options = DebugLaunchOptions(arguments: arguments)
        debug = options.isActive ? DebugSession(options: options) : nil

        let preferences: any PreferencesStore
        let sound: any SoundPlaying
        let libraryRoot: URL
        let deletionMode: DeletionMode
        if let debugRoot = options.libraryRoot {
            // A throwaway library: never touch the real notes or preferences,
            // stay quiet while scripted, and don't fill the Trash with test books.
            preferences = InMemoryPreferences(libraryRootPath: debugRoot.path(percentEncoded: false), authorName: "Josh")
            sound = SilentSoundPlayer()
            libraryRoot = debugRoot
            deletionMode = .removePermanently
        } else {
            let stored = UserDefaultsPreferences(defaults: .standard)
            if stored.authorName == nil {
                stored.authorName = NSFullUserName()
            }
            preferences = stored
            sound = AudioFileSoundPlayer()
            libraryRoot = Self.defaultLibraryRoot
            deletionMode = .moveToTrash
        }

        let measurer = FontGlyphMeasurer(fontName: FontRegistry.pixelFontName, size: 8)
        let dependencies = AppDependencies(
            makeRepository: { FileSystemLibraryRepository(rootURL: $0, deletionMode: deletionMode) },
            defaultLibraryRoot: libraryRoot,
            sound: sound,
            preferences: preferences,
            fitter: PageFitter(measurer: measurer)
        )
        app = AppModel(dependencies: dependencies)
    }

    /// Starts debug facilities, if any were requested.
    func didFinishLaunching() {
        debug?.start(app: app, libraryRoot: app.libraryRoot)
    }

    /// ~/Documents/Book and Quill
    private static var defaultLibraryRoot: URL {
        URL.documentsDirectory.appending(path: "Book and Quill", directoryHint: .isDirectory)
    }
}
