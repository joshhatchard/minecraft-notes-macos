import Foundation

/// User preferences that survive relaunch.
@MainActor
public protocol PreferencesStore: AnyObject {
    /// The library folder chosen by the user, or `nil` for the default.
    var libraryRootPath: String? { get set }
    /// The author name last used to sign a book.
    var authorName: String? { get set }
}

/// Preferences stored in `UserDefaults`.
@MainActor
public final class UserDefaultsPreferences: PreferencesStore {
    private enum Key {
        static let libraryRootPath = "libraryRootPath"
        static let authorName = "authorName"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var libraryRootPath: String? {
        get { defaults.string(forKey: Key.libraryRootPath) }
        set { defaults.set(newValue, forKey: Key.libraryRootPath) }
    }

    public var authorName: String? {
        get { defaults.string(forKey: Key.authorName) }
        set { defaults.set(newValue, forKey: Key.authorName) }
    }
}

/// Preferences kept in memory, for tests and previews.
@MainActor
public final class InMemoryPreferences: PreferencesStore {
    public var libraryRootPath: String?
    public var authorName: String?

    public init(libraryRootPath: String? = nil, authorName: String? = nil) {
        self.libraryRootPath = libraryRootPath
        self.authorName = authorName
    }
}
