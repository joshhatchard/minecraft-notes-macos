/// Measures how wide a character is when drawn on a page, in GUI pixels.
///
/// Page fitting is defined in terms of this protocol so the domain stays free of
/// any font or UI framework. The UI injects a measurer backed by the real font;
/// tests and headless code use ``MinecraftGlyphMetrics``.
public protocol GlyphMeasuring: Sendable {
    /// The horizontal advance of `character`, including inter-glyph spacing.
    func advance(of character: Character) -> Double
}

/// Advance widths of the Minecraft default font for printable ASCII, in GUI pixels.
///
/// The table matches the bundled pixel font at 8 pt (1 pt = 1 GUI pixel).
/// Characters outside the table use ``fallbackAdvance``.
public struct MinecraftGlyphMetrics: GlyphMeasuring {
    /// Advance used for characters the table does not know.
    public static let fallbackAdvance: Double = 6

    private static let narrowGroups: [(width: Double, characters: String)] = [
        (2, "!',.:;i|"),
        (3, "`l"),
        (4, " \"()*I[]t{}"),
        (5, "<>fk"),
        (7, "@~"),
    ]

    private static let table: [Character: Double] = {
        var table: [Character: Double] = [:]
        for group in narrowGroups {
            for character in group.characters {
                table[character] = group.width
            }
        }
        return table
    }()

    public init() {}

    public func advance(of character: Character) -> Double {
        if let width = Self.table[character] {
            return width
        }
        return Self.fallbackAdvance
    }
}
