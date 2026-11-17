import BookCore
import Foundation

/// A ``LibraryRepository`` stored as plain folders and files:
///
/// ```
/// <root>/library.json                              chest order
/// <root>/<Chest>/chest.json                        shelf order
/// <root>/<Chest>/<Shelf>/<Book>.book/book.json     title, author, signed, dates, slot
/// <root>/<Chest>/<Shelf>/<Book>.book/pages/001.md  one plain-text file per page
/// ```
///
/// Every write is atomic (temporary file + rename). Moving books or shelves
/// moves real folders. Unreadable metadata never blocks access to pages: the
/// book falls back to defaults and the bad file is kept as a backup on save.
public final class FileSystemLibraryRepository: LibraryRepository {
    /// The library root folder.
    public let rootURL: URL
    let files: FileSystemAccess
    let now: @Sendable () -> Date

    /// - Parameters:
    ///   - rootURL: Library folder; created on first use.
    ///   - deletionMode: Whether deletes go to the Trash (default) or are permanent.
    ///   - now: Clock used for book timestamps.
    public init(
        rootURL: URL,
        deletionMode: DeletionMode = .moveToTrash,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.rootURL = rootURL
        self.files = FileSystemAccess(deletionMode: deletionMode)
        self.now = now
    }

    // MARK: Locations

    func url(of chest: ChestID) -> URL {
        rootURL.appending(path: chest.name, directoryHint: .isDirectory)
    }

    func url(of shelf: ShelfID) -> URL {
        url(of: shelf.chest).appending(path: shelf.name, directoryHint: .isDirectory)
    }

    func url(of book: BookID) -> URL {
        url(of: book.shelf).appending(path: "\(book.folderName).\(StorageFormat.bookExtension)", directoryHint: .isDirectory)
    }

    func existingURL(of chest: ChestID) throws(LibraryError) -> URL {
        let url = url(of: chest)
        guard files.isDirectory(url) else { throw .notFound("The chest “\(chest.name)”") }
        return url
    }

    func existingURL(of shelf: ShelfID) throws(LibraryError) -> URL {
        let url = url(of: shelf)
        guard files.isDirectory(url) else { throw .notFound("The shelf “\(shelf.name)”") }
        return url
    }

    func existingURL(of book: BookID) throws(LibraryError) -> URL {
        let url = url(of: book)
        guard files.isDirectory(url) else { throw .notFound("The book “\(book.folderName)”") }
        return url
    }

    func ensureRootExists() throws(LibraryError) {
        if !files.isDirectory(rootURL) {
            try files.createFolder(rootURL)
        }
    }
}
