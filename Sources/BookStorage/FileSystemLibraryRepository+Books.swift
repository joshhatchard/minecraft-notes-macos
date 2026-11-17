import BookCore
import Foundation

// Books: `.book` folder packages holding book.json and pages/NNN.md.
extension FileSystemLibraryRepository {
    public func createBook(titled title: String, in shelf: ShelfID, slot: Int?) throws(LibraryError) -> BookID {
        let shelfURL = try existingURL(of: shelf)
        let validTitle = try FileNaming.validTitle(title)
        if let slot, slot < 0 { throw .invalidSlot(slot) }
        let occupied = Set(try books(on: shelf).map(\.slot))
        let targetSlot = slot.flatMap { occupied.contains($0) ? nil : $0 }
            ?? ShelfLayout.firstFreeSlot(occupied: occupied)

        let folder = try uniqueBookFolder(FileNaming.sanitize(validTitle), in: shelfURL)
        let id = BookID(shelf: shelf, folderName: folder)
        let bookURL = url(of: id)
        let created = now()
        try files.createFolder(bookURL.appending(path: StorageFormat.pagesFolder, directoryHint: .isDirectory))
        try writePages([Page()], in: bookURL)
        try files.writeJSON(
            BookMetadata(title: validTitle, author: "", signed: false, createdAt: created, updatedAt: created, slot: targetSlot),
            to: bookURL.appending(path: StorageFormat.bookMetadataFile)
        )
        return id
    }

    public func renameBook(_ book: BookID, to title: String) throws(LibraryError) -> BookID {
        let source = try existingURL(of: book)
        let validTitle = try FileNaming.validTitle(title)
        let shelfURL = url(of: book.shelf)
        let others = try files.entries(in: shelfURL)
            .filter { $0 != "\(book.folderName).\(StorageFormat.bookExtension)" }
        let folder = FileNaming.unique(FileNaming.sanitize(validTitle), suffix: ".\(StorageFormat.bookExtension)", among: others)
        let renamed = BookID(shelf: book.shelf, folderName: folder)
        try files.move(source, to: url(of: renamed))
        try updateMetadata(of: renamed) { metadata in
            metadata.title = validTitle
            metadata.updatedAt = now()
        }
        return renamed
    }

    public func deleteBook(_ book: BookID) throws(LibraryError) {
        try files.delete(try existingURL(of: book))
    }

    public func moveBook(_ book: BookID, to shelf: ShelfID, slot: Int) throws(LibraryError) -> BookMove {
        guard slot >= 0 else { throw .invalidSlot(slot) }
        _ = try existingURL(of: book)
        _ = try existingURL(of: shelf)
        guard let sourceSlot = try books(on: book.shelf).first(where: { $0.id == book })?.slot else {
            throw .notFound("The book “\(book.folderName)”")
        }
        if book.shelf == shelf, sourceSlot == slot {
            return BookMove(moved: book, displaced: nil)
        }
        let occupant = try books(on: shelf).first { $0.slot == slot && $0.id != book }

        let moved = try relocate(book, to: shelf)
        try updateMetadata(of: moved) { $0.slot = slot }
        var displaced: BookID?
        if let occupant {
            let swapped = try relocate(occupant.id, to: book.shelf)
            try updateMetadata(of: swapped) { $0.slot = sourceSlot }
            displaced = swapped
        }
        return BookMove(moved: moved, displaced: displaced)
    }

    public func loadBook(_ book: BookID) throws(LibraryError) -> Book {
        let bookURL = try existingURL(of: book)
        let metadata = metadataOrFallback(for: book)
        let pages = try readPages(in: bookURL)
        return Book(
            title: metadata.title,
            author: metadata.author,
            isSigned: metadata.signed,
            createdAt: metadata.createdAt,
            updatedAt: metadata.updatedAt,
            pages: pages
        )
    }

    public func saveBook(_ book: Book, as id: BookID) throws(LibraryError) {
        let bookURL = try existingURL(of: id)
        try writePages(book.pages, in: bookURL)
        var slot = metadataIfValid(for: id)?.slot
        if slot == nil {
            slot = try books(on: id.shelf).first { $0.id == id }?.slot
        }
        try writeMetadata(
            BookMetadata(
                title: book.title,
                author: book.author,
                signed: book.isSigned,
                createdAt: book.createdAt,
                updatedAt: book.updatedAt,
                slot: slot
            ),
            for: id
        )
    }

    // MARK: Listing

    /// The books on a shelf with resolved, unique slots.
    func books(on shelf: ShelfID) throws(LibraryError) -> [BookSummary] {
        let shelfURL = try existingURL(of: shelf)
        let suffix = ".\(StorageFormat.bookExtension)"
        let folders = try files.subfolders(of: shelfURL)
            .filter { $0.hasSuffix(suffix) && $0.count > suffix.count }
            .map { String($0.dropLast(suffix.count)) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let entries = folders.map { folder in
            let id = BookID(shelf: shelf, folderName: folder)
            return (id: id, metadata: metadataOrFallback(for: id))
        }
        let slots = SlotAssignment.assign(entries.map { (key: $0.id, slot: $0.metadata.slot) })
        return entries.map { entry in
            BookSummary(
                id: entry.id,
                title: entry.metadata.title,
                author: entry.metadata.author,
                isSigned: entry.metadata.signed,
                slot: slots[entry.id] ?? 0
            )
        }
    }

    // MARK: Metadata

    private func metadataURL(for book: BookID) -> URL {
        url(of: book).appending(path: StorageFormat.bookMetadataFile)
    }

    private func metadataIfValid(for book: BookID) -> BookMetadata? {
        files.decodeIfValid(BookMetadata.self, from: metadataURL(for: book))
    }

    /// Metadata from book.json, or defaults derived from the folder when it is
    /// missing or corrupted, so the pages always stay reachable.
    private func metadataOrFallback(for book: BookID) -> BookMetadata {
        if let metadata = metadataIfValid(for: book) {
            return metadata
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url(of: book).path(percentEncoded: false))
        let created = attributes?[.creationDate] as? Date ?? now()
        let modified = attributes?[.modificationDate] as? Date ?? created
        let title = String(book.folderName.prefix(BookLimits.maxTitleLength))
        return BookMetadata(title: title, author: "", signed: false, createdAt: created, updatedAt: modified, slot: nil)
    }

    private func updateMetadata(of book: BookID, _ change: (inout BookMetadata) -> Void) throws(LibraryError) {
        var metadata = metadataOrFallback(for: book)
        change(&metadata)
        try writeMetadata(metadata, for: book)
    }

    /// Writes book.json. An existing file that cannot be decoded is first
    /// preserved as `book.json.corrupt-<timestamp>` rather than overwritten.
    private func writeMetadata(_ metadata: BookMetadata, for book: BookID) throws(LibraryError) {
        let target = metadataURL(for: book)
        if files.exists(target), metadataIfValid(for: book) == nil {
            let stamp = Int(now().timeIntervalSince1970)
            let backup = target.deletingLastPathComponent()
                .appending(path: "\(StorageFormat.bookMetadataFile).corrupt-\(stamp)")
            try files.move(target, to: backup)
        }
        try files.writeJSON(metadata, to: target)
    }

    // MARK: Pages

    private func readPages(in bookURL: URL) throws(LibraryError) -> [Page] {
        let pagesURL = bookURL.appending(path: StorageFormat.pagesFolder, directoryHint: .isDirectory)
        guard files.isDirectory(pagesURL) else { return [] }
        let numbered = try files.entries(in: pagesURL)
            .compactMap { name in StorageFormat.pageNumber(ofFileName: name).map { (number: $0, name: name) } }
            .sorted { $0.number < $1.number }
        var pages: [Page] = []
        for entry in numbered {
            let data = try files.read(pagesURL.appending(path: entry.name))
            pages.append(Page(text: String(decoding: data, as: UTF8.self)))
        }
        return pages
    }

    /// Writes changed pages atomically, then removes page files beyond the book's length.
    private func writePages(_ pages: [Page], in bookURL: URL) throws(LibraryError) {
        let pagesURL = bookURL.appending(path: StorageFormat.pagesFolder, directoryHint: .isDirectory)
        try files.createFolder(pagesURL)
        var expected = Set<String>()
        for (index, page) in pages.enumerated() {
            let name = StorageFormat.pageFileName(forIndex: index)
            expected.insert(name)
            let fileURL = pagesURL.appending(path: name)
            let data = Data(page.text.utf8)
            if (try? Data(contentsOf: fileURL)) != data {
                try AtomicFileWriter.write(data, to: fileURL)
            }
        }
        for name in try files.entries(in: pagesURL)
        where StorageFormat.pageNumber(ofFileName: name) != nil && !expected.contains(name) {
            try files.delete(pagesURL.appending(path: name))
        }
    }

    // MARK: Moving

    private func relocate(_ book: BookID, to shelf: ShelfID) throws(LibraryError) -> BookID {
        guard book.shelf != shelf else { return book }
        let folder = try uniqueBookFolder(book.folderName, in: url(of: shelf))
        let moved = BookID(shelf: shelf, folderName: folder)
        try files.move(url(of: book), to: url(of: moved))
        return moved
    }

    private func uniqueBookFolder(_ base: String, in shelfURL: URL) throws(LibraryError) -> String {
        FileNaming.unique(base, suffix: ".\(StorageFormat.bookExtension)", among: try files.entries(in: shelfURL))
    }
}
