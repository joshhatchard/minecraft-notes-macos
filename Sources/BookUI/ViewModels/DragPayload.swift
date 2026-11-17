import BookCore
import Foundation

/// What is being dragged inside the app, encoded as a tagged string so drops
/// of unrelated text from other apps are ignored.
public enum DragPayload: Equatable, Codable, Sendable {
    case book(BookID)
    case shelf(ShelfID)

    private static let prefix = "bookandquill-drag:"

    /// The string carried by the drag.
    public var encoded: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return Self.prefix + String(decoding: data, as: UTF8.self)
    }

    /// Decodes a dragged string; `nil` for anything this app did not produce.
    public init?(encoded: String) {
        guard encoded.hasPrefix(Self.prefix),
            let payload = try? JSONDecoder().decode(DragPayload.self, from: Data(encoded.dropFirst(Self.prefix.count).utf8))
        else { return nil }
        self = payload
    }
}
