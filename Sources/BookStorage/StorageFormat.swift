import Foundation

/// On-disk JSON formats and file names. All files are small and human-readable.
enum StorageFormat {
    static let libraryIndexFile = "library.json"
    static let chestIndexFile = "chest.json"
    static let bookMetadataFile = "book.json"
    static let pagesFolder = "pages"
    static let bookExtension = "book"
    static let pageExtension = "md"

    /// `001.md`, `002.md` … for a zero-based page index.
    static func pageFileName(forIndex index: Int) -> String {
        String(format: "%03d.%@", index + 1, pageExtension)
    }

    /// The one-based page number encoded in a page file name, if it is one.
    static func pageNumber(ofFileName name: String) -> Int? {
        guard name.hasSuffix(".\(pageExtension)") else { return nil }
        let stem = name.dropLast(pageExtension.count + 1)
        guard !stem.isEmpty, stem.allSatisfy(\.isASCII), stem.allSatisfy(\.isNumber) else { return nil }
        return Int(stem)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

/// `library.json` at the root: the display order of chests.
struct LibraryIndex: Codable, Equatable {
    var version = 1
    var chestOrder: [String] = []
}

/// `chest.json` in each chest folder: the display order of shelves.
struct ChestIndex: Codable, Equatable {
    var version = 1
    var shelfOrder: [String] = []
}

/// `book.json` in each `.book` folder.
struct BookMetadata: Codable, Equatable {
    var version = 1
    var title: String
    var author: String
    var signed: Bool
    var createdAt: Date
    var updatedAt: Date
    /// Zero-based shelf slot; `nil` lets the shelf place the book.
    var slot: Int?
}
