import BookAudio
import BookCore
import BookStorage
import BookUI
import Foundation

/// Dependency wiring: the one place concrete implementations are chosen.
@MainActor
final class AppComposition {
    let app: AppModel

    init() {
        FontRegistry.registerBundledFonts()
        let preferences = UserDefaultsPreferences(defaults: .standard)
        if preferences.authorName == nil {
            preferences.authorName = NSFullUserName()
        }
        let measurer = FontGlyphMeasurer(fontName: FontRegistry.pixelFontName, size: 8)
        let dependencies = AppDependencies(
            makeRepository: { FileSystemLibraryRepository(rootURL: $0, deletionMode: .moveToTrash) },
            defaultLibraryRoot: Self.defaultLibraryRoot,
            sound: AudioFileSoundPlayer(),
            preferences: preferences,
            fitter: PageFitter(measurer: measurer)
        )
        app = AppModel(dependencies: dependencies)
    }

    /// ~/Documents/Book and Quill
    private static var defaultLibraryRoot: URL {
        URL.documentsDirectory.appending(path: "Book and Quill", directoryHint: .isDirectory)
    }
}
