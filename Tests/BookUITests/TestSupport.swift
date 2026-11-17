import BookAudio
import BookCore
import BookStorage
import BookUI
import Foundation

/// Records which sound effects were played.
@MainActor
final class SoundSpy: SoundPlaying {
    private(set) var played: [SoundEffect] = []

    func play(_ effect: SoundEffect) {
        played.append(effect)
    }
}

let testDate = Date(timeIntervalSince1970: 1_700_000_000)

/// An app model over an in-memory library with one chest, shelf and book.
@MainActor
struct Fixture {
    let repository = InMemoryLibraryRepository(now: { testDate })
    let sound = SoundSpy()
    let preferences = InMemoryPreferences(authorName: "Josh")
    let chest: ChestID
    let shelf: ShelfID
    let book: BookID

    init() throws {
        chest = try repository.createChest(named: "Semester 1")
        shelf = try repository.createShelf(named: "Physics", in: chest)
        book = try repository.createBook(titled: "Week 1", in: shelf, slot: nil)
    }

    func makeApp(autosaveDelay: Duration = .seconds(60)) -> AppModel {
        let repository = self.repository
        return AppModel(
            dependencies: AppDependencies(
                makeRepository: { _ in repository },
                defaultLibraryRoot: URL(filePath: "/tmp/unused"),
                sound: sound,
                preferences: preferences,
                fitter: PageFitter(),
                autosaveDelay: autosaveDelay,
                now: { testDate }
            ))
    }

    func makeEditor(autosaveDelay: Duration = .seconds(60)) throws -> BookEditorViewModel {
        BookEditorViewModel(
            bookID: book,
            book: try repository.loadBook(book),
            repository: repository,
            sound: sound,
            preferences: preferences,
            fitter: PageFitter(),
            autosaveDelay: autosaveDelay,
            now: { testDate }
        )
    }
}
