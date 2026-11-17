import BookCore
import BookStorage
import Foundation
import Testing

/// A uniquely named folder under the system temporary directory, removed on deinit.
final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "BookAndQuillTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func contents(of relativePath: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: url.appending(path: relativePath).path(percentEncoded: false)).sorted()
    }

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: url.appending(path: relativePath).path(percentEncoded: false))
    }

    func read(_ relativePath: String) throws -> String {
        try String(contentsOf: url.appending(path: relativePath), encoding: .utf8)
    }

    func write(_ text: String, to relativePath: String) throws {
        try Data(text.utf8).write(to: url.appending(path: relativePath))
    }
}

let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

/// Builds a repository together with whatever keeps its storage alive.
enum RepositoryKind: String, CaseIterable, CustomTestStringConvertible {
    case fileSystem
    case inMemory

    var testDescription: String { rawValue }

    func make() throws -> (repository: any LibraryRepository, keepAlive: TemporaryFolder?) {
        switch self {
        case .fileSystem:
            let folder = try TemporaryFolder()
            let repository = FileSystemLibraryRepository(
                rootURL: folder.url.appending(path: "Library"),
                deletionMode: .removePermanently,
                now: { fixedDate }
            )
            return (repository, folder)
        case .inMemory:
            return (InMemoryLibraryRepository(now: { fixedDate }), nil)
        }
    }
}
