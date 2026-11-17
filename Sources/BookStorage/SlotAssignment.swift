/// Resolves the slot of every book on a shelf.
enum SlotAssignment {
    /// Gives each key a unique, non-negative slot.
    ///
    /// Keys are processed in the given order: a key keeps its requested slot if
    /// that slot is valid and not yet taken; otherwise it gets the first free
    /// slot. This repairs missing, negative or duplicated slots from hand-edited
    /// or corrupted metadata deterministically, without writing anything.
    static func assign<Key: Hashable>(_ requests: [(key: Key, slot: Int?)]) -> [Key: Int] {
        var taken = Set<Int>()
        var result: [Key: Int] = [:]
        var unplaced: [Key] = []
        for request in requests {
            if let slot = request.slot, slot >= 0, taken.insert(slot).inserted {
                result[request.key] = slot
            } else {
                unplaced.append(request.key)
            }
        }
        var next = 0
        for key in unplaced {
            while taken.contains(next) { next += 1 }
            taken.insert(next)
            result[key] = next
        }
        return result
    }
}
