import Foundation

/// How deleted items leave the library.
public enum DeletionMode: Sendable {
    /// Move to the user's Trash so a mistaken delete can be undone (the app default).
    case moveToTrash
    /// Remove permanently (used by tests and temporary libraries).
    case removePermanently
}

/// Thin, error-mapping wrapper over `FileManager` used by the file-system repository.
struct FileSystemAccess: Sendable {
    let deletionMode: DeletionMode

    private var fileManager: FileManager { .default }

    func exists(_ url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path(percentEncoded: false))
    }

    func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    /// Visible entry names in a folder (hidden files and temporaries skipped).
    func entries(in folder: URL) throws(LibraryError) -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
                .filter { !$0.hasPrefix(".") }
        } catch {
            throw .io("Could not read \(folder.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Names of visible sub-folders of `folder`.
    func subfolders(of folder: URL) throws(LibraryError) -> [String] {
        try entries(in: folder).filter { isDirectory(folder.appending(path: $0, directoryHint: .isDirectory)) }
    }

    func createFolder(_ url: URL) throws(LibraryError) {
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw .io("Could not create \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Moves or renames an item. Case-only renames go through a temporary name
    /// because the default macOS file system is case-insensitive.
    func move(_ source: URL, to destination: URL) throws(LibraryError) {
        guard source.standardizedFileURL != destination.standardizedFileURL else { return }
        do {
            if source.path(percentEncoded: false).lowercased() == destination.path(percentEncoded: false).lowercased() {
                let intermediate = source.deletingLastPathComponent()
                    .appending(path: ".rename-\(UUID().uuidString)")
                try fileManager.moveItem(at: source, to: intermediate)
                try fileManager.moveItem(at: intermediate, to: destination)
            } else {
                try fileManager.moveItem(at: source, to: destination)
            }
        } catch {
            throw .io("Could not move \(source.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func delete(_ url: URL) throws(LibraryError) {
        do {
            switch deletionMode {
            case .moveToTrash: try fileManager.trashItem(at: url, resultingItemURL: nil)
            case .removePermanently: try fileManager.removeItem(at: url)
            }
        } catch {
            throw .io("Could not delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    func read(_ url: URL) throws(LibraryError) -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw .io("Could not read \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    /// Decodes JSON, returning `nil` when the file is missing or unreadable as `T`.
    func decodeIfValid<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? StorageFormat.decoder.decode(type, from: data)
    }

    func writeJSON(_ value: some Encodable, to url: URL) throws(LibraryError) {
        let data: Data
        do {
            data = try StorageFormat.encoder.encode(value)
        } catch {
            throw .io("Could not encode \(url.lastPathComponent): \(error.localizedDescription)")
        }
        try AtomicFileWriter.write(data, to: url)
    }
}
