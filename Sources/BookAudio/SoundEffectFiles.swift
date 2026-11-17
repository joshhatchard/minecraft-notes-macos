import BookAssets

extension SoundEffect {
    /// Candidate files for this effect; one is picked at random each time,
    /// like Minecraft's sound variants.
    var files: [AssetCatalog.SoundFile] {
        switch self {
        case .pageTurn: [.pageTurn1, .pageTurn2, .pageTurn3]
        case .click: [.click]
        case .chestOpen: [.insert]
        case .bookOpen: [.pickup]
        case .bookPlace: [.insert]
        }
    }
}
