import BookCore
import Foundation

/// Result of moving a book onto a shelf slot.
public struct BookMove: Equatable, Sendable {
    /// New identity of the book that was moved.
    public let moved: BookID
    /// New identity of the book that was in the target slot and was swapped
    /// into the moved book's old slot, if there was one.
    public let displaced: BookID?

    public init(moved: BookID, displaced: BookID?) {
        self.moved = moved
        self.displaced = displaced
    }
}

/// Storage for the chest → shelf → book hierarchy.
///
/// Identities are location based: renaming or moving an item returns its new
/// identity, and the old one stops resolving. Names typed by the user are
/// validated and made safe for the file system; on collision a numeric suffix
/// is added ("Maths 2").
public protocol LibraryRepository: Sendable {
    /// All chests in display order.
    func chests() throws(LibraryError) -> [ChestSummary]
    /// Creates a chest and returns its identity.
    func createChest(named name: String) throws(LibraryError) -> ChestID
    /// Renames a chest and returns its new identity.
    func renameChest(_ chest: ChestID, to name: String) throws(LibraryError) -> ChestID
    /// Deletes a chest and everything in it.
    func deleteChest(_ chest: ChestID) throws(LibraryError)

    /// All shelves of a chest in display order, with their books.
    func shelves(in chest: ChestID) throws(LibraryError) -> [ShelfSummary]
    /// Creates a shelf at the end of a chest.
    func createShelf(named name: String, in chest: ChestID) throws(LibraryError) -> ShelfID
    /// Renames a shelf and returns its new identity.
    func renameShelf(_ shelf: ShelfID, to name: String) throws(LibraryError) -> ShelfID
    /// Deletes a shelf and all its books.
    func deleteShelf(_ shelf: ShelfID) throws(LibraryError)
    /// Moves a shelf (with its books) into another chest.
    func moveShelf(_ shelf: ShelfID, to chest: ChestID) throws(LibraryError) -> ShelfID

    /// Creates an empty book. `slot` defaults to the shelf's first free slot.
    func createBook(titled title: String, in shelf: ShelfID, slot: Int?) throws(LibraryError) -> BookID
    /// Changes a book's title (and folder name) and returns its new identity.
    func renameBook(_ book: BookID, to title: String) throws(LibraryError) -> BookID
    /// Deletes a book.
    func deleteBook(_ book: BookID) throws(LibraryError)
    /// Moves a book to a slot on any shelf of the same library. A book already
    /// in that slot swaps into the moved book's previous place.
    func moveBook(_ book: BookID, to shelf: ShelfID, slot: Int) throws(LibraryError) -> BookMove

    /// Loads a book with all its pages.
    func loadBook(_ book: BookID) throws(LibraryError) -> Book
    /// Saves a book's metadata and pages.
    func saveBook(_ book: Book, as id: BookID) throws(LibraryError)
}

/// Errors raised by a ``LibraryRepository``.
public enum LibraryError: Error, Equatable, Sendable, LocalizedError {
    /// The typed name is not acceptable.
    case invalidName(NameIssue)
    /// The chest, shelf or book no longer exists.
    case notFound(String)
    /// A slot index was negative.
    case invalidSlot(Int)
    /// The underlying storage failed.
    case io(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(.empty): "Please enter a name."
        case .invalidName(.tooLong(let max)): "Names can be at most \(max) characters."
        case .invalidName(.containsControlCharacters): "Names cannot contain line breaks."
        case .notFound(let item): "\(item) could not be found. It may have been moved or deleted."
        case .invalidSlot(let slot): "Slot \(slot) does not exist."
        case .io(let message): message
        }
    }
}
