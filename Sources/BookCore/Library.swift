/// Identifies a chest (a semester) by its folder name.
public struct ChestID: Hashable, Sendable, Codable {
    /// Folder name of the chest, also its display name.
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

/// Identifies a shelf (a subject) inside a chest.
public struct ShelfID: Hashable, Sendable, Codable {
    /// The chest holding the shelf.
    public let chest: ChestID
    /// Folder name of the shelf, also its display name.
    public let name: String

    public init(chest: ChestID, name: String) {
        self.chest = chest
        self.name = name
    }
}

/// Identifies a book inside a shelf.
public struct BookID: Hashable, Sendable, Codable {
    /// The shelf holding the book.
    public let shelf: ShelfID
    /// Folder name of the book without its `.book` extension.
    public let folderName: String

    public init(shelf: ShelfID, folderName: String) {
        self.shelf = shelf
        self.folderName = folderName
    }
}

/// A chest as listed on the home screen.
public struct ChestSummary: Identifiable, Equatable, Sendable {
    public let id: ChestID
    /// Number of shelves in the chest.
    public let shelfCount: Int

    public init(id: ChestID, shelfCount: Int) {
        self.id = id
        self.shelfCount = shelfCount
    }

    /// Display name.
    public var name: String { id.name }
}

/// A book as shown in a shelf slot.
public struct BookSummary: Identifiable, Equatable, Sendable {
    public let id: BookID
    public let title: String
    public let author: String
    public let isSigned: Bool
    /// Zero-based slot on the shelf. Unique within a shelf.
    public let slot: Int

    public init(id: BookID, title: String, author: String, isSigned: Bool, slot: Int) {
        self.id = id
        self.title = title
        self.author = author
        self.isSigned = isSigned
        self.slot = slot
    }
}

/// A shelf with the books on it.
public struct ShelfSummary: Identifiable, Equatable, Sendable {
    public let id: ShelfID
    /// Books on the shelf, sorted by slot.
    public let books: [BookSummary]

    public init(id: ShelfID, books: [BookSummary]) {
        self.id = id
        self.books = books.sorted { $0.slot < $1.slot }
    }

    /// Display name.
    public var name: String { id.name }

    /// The book in `slot`, if any.
    public func book(inSlot slot: Int) -> BookSummary? {
        books.first { $0.slot == slot }
    }
}
