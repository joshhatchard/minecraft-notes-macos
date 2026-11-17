import BookCore
import BookStorage
import Observation

/// Home screen: the list of chests (semesters).
@MainActor
@Observable
public final class ChestListViewModel: ErrorReporting {
    /// Chests in display order.
    public private(set) var chests: [ChestSummary] = []
    public var errorMessage: String?

    @ObservationIgnored private let repository: any LibraryRepository

    public init(repository: any LibraryRepository) {
        self.repository = repository
    }

    /// Re-reads the chests from storage.
    public func reload() {
        if let loaded = attempt({ () throws(LibraryError) in try repository.chests() }) {
            chests = loaded
        }
    }

    /// Creates a chest. Returns `false` and sets ``errorMessage`` on failure.
    @discardableResult
    public func createChest(named name: String) -> Bool {
        let created = attempt { () throws(LibraryError) in try repository.createChest(named: name) }
        reload()
        return created != nil
    }

    /// Renames a chest. Returns `false` and sets ``errorMessage`` on failure.
    @discardableResult
    public func renameChest(_ chest: ChestID, to name: String) -> Bool {
        let renamed = attempt { () throws(LibraryError) in try repository.renameChest(chest, to: name) }
        reload()
        return renamed != nil
    }

    /// Deletes a chest and its contents.
    public func deleteChest(_ chest: ChestID) {
        attempt { () throws(LibraryError) in try repository.deleteChest(chest) }
        reload()
    }
}
