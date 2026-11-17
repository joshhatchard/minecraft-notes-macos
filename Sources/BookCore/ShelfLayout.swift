/// Slot arithmetic for shelves drawn as chiseled bookshelf blocks.
///
/// Each block holds six books (two rows of three). A shelf shows as many blocks
/// as it needs, and always at least one free slot so there is somewhere to
/// drop or create a book.
public enum ShelfLayout {
    /// Book slots per chiseled bookshelf block.
    public static let slotsPerBlock = 6

    /// The lowest slot index not in `occupied`.
    public static func firstFreeSlot(occupied: Set<Int>) -> Int {
        var slot = 0
        while occupied.contains(slot) {
            slot += 1
        }
        return slot
    }

    /// Number of blocks to draw so every occupied slot is visible and at least
    /// one slot is free.
    public static func blockCount(occupied: Set<Int>) -> Int {
        let needed = max(occupied.max().map { $0 + 1 } ?? 0, firstFreeSlot(occupied: occupied) + 1)
        return max(1, (needed + slotsPerBlock - 1) / slotsPerBlock)
    }

    /// The slot indices drawn by block number `block`.
    public static func slots(inBlock block: Int) -> Range<Int> {
        (block * slotsPerBlock)..<((block + 1) * slotsPerBlock)
    }
}
