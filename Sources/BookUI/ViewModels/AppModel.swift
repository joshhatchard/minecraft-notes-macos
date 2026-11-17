import BookAudio
import BookCore
import BookStorage
import Foundation
import Observation

/// Which screen is showing.
public enum Route: Equatable, Sendable {
    /// Home: the list of chests.
    case chests
    /// Inside a chest: its shelves.
    case chest(ChestID)
    /// The book editor.
    case book(BookID)
}

/// Everything the app model needs from the outside world.
@MainActor
public struct AppDependencies {
    /// Builds a repository for a library folder.
    public var makeRepository: (URL) -> any LibraryRepository
    /// The library folder used when the user has not chosen one.
    public var defaultLibraryRoot: URL
    public var sound: any SoundPlaying
    public var preferences: any PreferencesStore
    /// Page rules, with the measurer matching the rendered font.
    public var fitter: PageFitter
    /// Quiet period after the last edit before a book is written to disk.
    public var autosaveDelay: Duration
    public var now: () -> Date

    public init(
        makeRepository: @escaping (URL) -> any LibraryRepository,
        defaultLibraryRoot: URL,
        sound: any SoundPlaying,
        preferences: any PreferencesStore,
        fitter: PageFitter,
        autosaveDelay: Duration = .milliseconds(600),
        now: @escaping () -> Date = { Date() }
    ) {
        self.makeRepository = makeRepository
        self.defaultLibraryRoot = defaultLibraryRoot
        self.sound = sound
        self.preferences = preferences
        self.fitter = fitter
        self.autosaveDelay = autosaveDelay
        self.now = now
    }
}

/// Root of the interface: navigation between screens and the screen view models.
@MainActor
@Observable
public final class AppModel {
    /// The visible screen.
    public private(set) var route: Route = .chests
    /// Home screen model.
    public private(set) var chestList: ChestListViewModel
    /// Open chest model, while a chest or book is open.
    public private(set) var chest: ChestViewModel?
    /// Open book model, while a book is open.
    public private(set) var editor: BookEditorViewModel?
    /// The library folder in use.
    public private(set) var libraryRoot: URL

    @ObservationIgnored private var repository: any LibraryRepository
    @ObservationIgnored private let dependencies: AppDependencies

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let root =
            dependencies.preferences.libraryRootPath.map { URL(filePath: $0, directoryHint: .isDirectory) }
            ?? dependencies.defaultLibraryRoot
        let repository = dependencies.makeRepository(root)
        self.libraryRoot = root
        self.repository = repository
        self.chestList = ChestListViewModel(repository: repository)
        chestList.reload()
    }

    /// Plays an interface sound effect.
    public func play(_ effect: SoundEffect) {
        dependencies.sound.play(effect)
    }

    /// The author name remembered from the last signing.
    public var authorName: String {
        get { dependencies.preferences.authorName ?? "" }
        set { dependencies.preferences.authorName = newValue }
    }

    // MARK: Navigation

    /// Opens a chest to show its shelves.
    public func openChest(_ id: ChestID) {
        let model = ChestViewModel(chestID: id, repository: repository, sound: dependencies.sound)
        model.reload()
        chest = model
        route = .chest(id)
        dependencies.sound.play(.chestOpen)
    }

    /// Opens a book in the editor.
    public func openBook(_ id: BookID) {
        guard closeEditor() else { return }
        if chest?.chestID != id.shelf.chest {
            chest = ChestViewModel(chestID: id.shelf.chest, repository: repository, sound: dependencies.sound)
        }
        let loaded: Book
        do {
            loaded = try repository.loadBook(id)
        } catch {
            chest?.errorMessage = error.errorDescription
            return
        }
        editor = BookEditorViewModel(
            bookID: id,
            book: loaded,
            repository: repository,
            sound: dependencies.sound,
            preferences: dependencies.preferences,
            fitter: dependencies.fitter,
            autosaveDelay: dependencies.autosaveDelay,
            now: dependencies.now
        )
        route = .book(id)
        dependencies.sound.play(.bookOpen)
    }

    /// Goes up one level: book → chest → home. Unsaved book changes are saved
    /// first; if that fails the book stays open so nothing is lost.
    public func goBack() {
        switch route {
        case .chests:
            return
        case .chest:
            chest = nil
            route = .chests
            chestList.reload()
        case .book:
            guard let editor, closeEditor() else { return }
            let chestID = editor.bookID.shelf.chest
            if chest == nil {
                chest = ChestViewModel(chestID: chestID, repository: repository, sound: dependencies.sound)
            }
            chest?.reload()
            route = .chest(chestID)
        }
    }

    /// Writes any pending edits. Call before quitting or going inactive.
    @discardableResult
    public func flushPendingChanges() -> Bool {
        editor?.flush() ?? true
    }

    /// Switches to another library folder and returns to the home screen.
    public func changeLibraryRoot(to url: URL) {
        guard closeEditor() else { return }
        dependencies.preferences.libraryRootPath = url.path(percentEncoded: false)
        libraryRoot = url
        repository = dependencies.makeRepository(url)
        chest = nil
        chestList = ChestListViewModel(repository: repository)
        chestList.reload()
        route = .chests
    }

    /// Saves and closes the editor. Returns `false` if saving failed.
    private func closeEditor() -> Bool {
        guard let editor else { return true }
        guard editor.flush() else { return false }
        self.editor = nil
        return true
    }
}
