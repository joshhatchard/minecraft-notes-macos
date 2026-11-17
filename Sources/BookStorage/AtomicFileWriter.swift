import Darwin
import Foundation

/// Writes files so readers only ever see the old or the new contents.
enum AtomicFileWriter {
    /// Writes `data` to a temporary file in the destination folder, flushes it
    /// to disk, then renames it over `url` (an atomic replace on APFS/HFS+).
    static func write(_ data: Data, to url: URL) throws(LibraryError) {
        let folder = url.deletingLastPathComponent()
        let temporary = folder.appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            guard FileManager.default.createFile(atPath: temporary.path(percentEncoded: false), contents: nil) else {
                throw LibraryError.io("Could not create a temporary file in \(folder.lastPathComponent).")
            }
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }
            try handle.write(contentsOf: data)
            try handle.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw (error as? LibraryError) ?? .io("Could not write \(url.lastPathComponent): \(error.localizedDescription)")
        }
        guard rename(temporary.path(percentEncoded: false), url.path(percentEncoded: false)) == 0 else {
            let reason = String(cString: strerror(errno))
            try? FileManager.default.removeItem(at: temporary)
            throw .io("Could not save \(url.lastPathComponent): \(reason)")
        }
    }
}
