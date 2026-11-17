import CoreGraphics

/// Positions on the book screen in GUI pixels, following Minecraft's book
/// edit screen. The canvas is 200 wide so the two 98-pixel buttons below the
/// book (with a 4-pixel gap) line up exactly as in the game.
enum BookCanvasGeometry {
    static let canvasSize = CGSize(width: 200, height: 216)
    /// The page region of book.png (the rest of the 256×256 atlas is unused).
    static let bookTextureCrop = CGRect(x: 0, y: 0, width: 192, height: 192)
    static let bookOrigin = CGPoint(x: 4, y: 0)

    /// Top-left of the writable text area.
    static let textOrigin = CGPoint(x: bookOrigin.x + 36, y: 30)
    /// Right edge of the "Page X of Y" label.
    static let pageLabelTrailingX = bookOrigin.x + 148
    static let pageLabelTop: CGFloat = 16

    static let arrowSize = CGSize(width: 23, height: 13)
    static let forwardArrowOrigin = CGPoint(x: bookOrigin.x + 116, y: 157)
    static let backArrowOrigin = CGPoint(x: bookOrigin.x + 43, y: 157)

    static let buttonTop: CGFloat = 196
    static let halfButtonWidth: CGFloat = 98
    static let fullButtonWidth: CGFloat = 200
    static let secondButtonX: CGFloat = 102

    /// Signing screen rows.
    static let signHeadingTop: CGFloat = 32
    static let signTitleTop: CGFloat = 40
    static let signAuthorTop: CGFloat = 62
    static let signWarningTop: CGFloat = 88

    /// Largest integer scale at which the canvas fits in `size` (at least 1).
    static func scale(fitting size: CGSize) -> CGFloat {
        let horizontal = (size.width / canvasSize.width).rounded(.down)
        let vertical = (size.height / canvasSize.height).rounded(.down)
        return max(1, min(horizontal, vertical))
    }
}
