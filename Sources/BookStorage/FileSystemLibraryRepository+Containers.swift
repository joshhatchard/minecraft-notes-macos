import BookCore
import Foundation

// Chests and shelves: plain folders whose order lives in small JSON indexes.
extension FileSystemLibraryRepository {
    public func chests() throws(LibraryError) -> [ChestSummary] {
        try ensureRootExists()
        var summaries: [ChestSummary] = []
        for name in try orderedChestNames() {
            let shelfFolders = try shelfFolderNames(in: rootURL.appending(path: name, directoryHint: .isDirectory))
            summaries.append(ChestSummary(id: ChestID(name: name), shelfCount: shelfFolders.count))
        }
        return summaries
    }

    public func createChest(named name: String) throws(LibraryError) -> ChestID {
        try ensureRootExists()
        let base = try FileNaming.containerFolderName(for: name)
        let folder = FileNaming.unique(base, among: try files.entries(in: rootURL))
        try files.createFolder(rootURL.appending(path: folder, directoryHint: .isDirectory))
        try writeLibraryIndex(order: try orderedChestNames())
        return ChestID(name: folder)
    }

    public func renameChest(_ chest: ChestID, to name: String) throws(LibraryError) -> ChestID {
        let source = try existingURL(of: chest)
        let base = try FileNaming.containerFolderName(for: name)
        let others = try files.entries(in: rootURL).filter { $0 != chest.name }
        let folder = FileNaming.unique(base, among: others)
        let order = try orderedChestNames().map { $0 == chest.name ? folder : $0 }
        try files.move(source, to: rootURL.appending(path: folder, directoryHint: .isDirectory))
        try writeLibraryIndex(order: order)
        return ChestID(name: folder)
    }

    public func deleteChest(_ chest: ChestID) throws(LibraryError) {
        try files.delete(try existingURL(of: chest))
        try writeLibraryIndex(order: try orderedChestNames())
    }

    public func shelves(in chest: ChestID) throws(LibraryError) -> [ShelfSummary] {
        let chestURL = try existingURL(of: chest)
        var result: [ShelfSummary] = []
        for name in try orderedShelfNames(in: chestURL) {
            let id = ShelfID(chest: chest, name: name)
            result.append(ShelfSummary(id: id, books: try books(on: id)))
        }
        return result
    }

    public func createShelf(named name: String, in chest: ChestID) throws(LibraryError) -> ShelfID {
        let chestURL = try existingURL(of: chest)
        let base = try FileNaming.containerFolderName(for: name)
        let folder = try uniqueShelfFolder(base, in: chestURL)
        let order = try orderedShelfNames(in: chestURL) + [folder]
        try files.createFolder(chestURL.appending(path: folder, directoryHint: .isDirectory))
        try writeChestIndex(order: order, in: chestURL)
        return ShelfID(chest: chest, name: folder)
    }

    public func renameShelf(_ shelf: ShelfID, to name: String) throws(LibraryError) -> ShelfID {
        let source = try existingURL(of: shelf)
        let chestURL = url(of: shelf.chest)
        let base = try FileNaming.containerFolderName(for: name)
        let others = try files.entries(in: chestURL).filter { $0 != shelf.name }
        let folder = FileNaming.unique(base, among: others + Self.reservedChestEntries)
        let order = try orderedShelfNames(in: chestURL).map { $0 == shelf.name ? folder : $0 }
        try files.move(source, to: chestURL.appending(path: folder, directoryHint: .isDirectory))
        try writeChestIndex(order: order, in: chestURL)
        return ShelfID(chest: shelf.chest, name: folder)
    }

    public func deleteShelf(_ shelf: ShelfID) throws(LibraryError) {
        let chestURL = url(of: shelf.chest)
        try files.delete(try existingURL(of: shelf))
        try writeChestIndex(order: try orderedShelfNames(in: chestURL), in: chestURL)
    }

    public func moveShelf(_ shelf: ShelfID, to chest: ChestID) throws(LibraryError) -> ShelfID {
        guard shelf.chest != chest else {
            _ = try existingURL(of: shelf)
            return shelf
        }
        let source = try existingURL(of: shelf)
        let sourceChestURL = url(of: shelf.chest)
        let targetChestURL = try existingURL(of: chest)
        let folder = try uniqueShelfFolder(shelf.name, in: targetChestURL)
        let targetOrder = try orderedShelfNames(in: targetChestURL) + [folder]
        try files.move(source, to: targetChestURL.appending(path: folder, directoryHint: .isDirectory))
        try writeChestIndex(order: targetOrder, in: targetChestURL)
        try writeChestIndex(order: try orderedShelfNames(in: sourceChestURL), in: sourceChestURL)
        return ShelfID(chest: chest, name: folder)
    }

    // MARK: Helpers

    /// File names a shelf folder must never take inside a chest folder.
    private static let reservedChestEntries = [StorageFormat.chestIndexFile]

    private func uniqueShelfFolder(_ base: String, in chestURL: URL) throws(LibraryError) -> String {
        FileNaming.unique(base, among: try files.entries(in: chestURL) + Self.reservedChestEntries)
    }

    private func orderedChestNames() throws(LibraryError) -> [String] {
        let stored = files.decodeIfValid(LibraryIndex.self, from: libraryIndexURL)?.chestOrder ?? []
        return FileNaming.ordered(try files.subfolders(of: rootURL), by: stored)
    }

    private func orderedShelfNames(in chestURL: URL) throws(LibraryError) -> [String] {
        let indexURL = chestURL.appending(path: StorageFormat.chestIndexFile)
        let stored = files.decodeIfValid(ChestIndex.self, from: indexURL)?.shelfOrder ?? []
        return FileNaming.ordered(try shelfFolderNames(in: chestURL), by: stored)
    }

    private func shelfFolderNames(in chestURL: URL) throws(LibraryError) -> [String] {
        try files.subfolders(of: chestURL).filter { !$0.hasSuffix(".\(StorageFormat.bookExtension)") }
    }

    private var libraryIndexURL: URL {
        rootURL.appending(path: StorageFormat.libraryIndexFile)
    }

    private func writeLibraryIndex(order: [String]) throws(LibraryError) {
        try files.writeJSON(LibraryIndex(chestOrder: order), to: libraryIndexURL)
    }

    private func writeChestIndex(order: [String], in chestURL: URL) throws(LibraryError) {
        try files.writeJSON(ChestIndex(shelfOrder: order), to: chestURL.appending(path: StorageFormat.chestIndexFile))
    }
}
