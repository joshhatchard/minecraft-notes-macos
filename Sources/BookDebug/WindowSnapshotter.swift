import AppKit

/// Photographs the app's own windows from their view hierarchy.
///
/// This uses `NSView.cacheDisplay(in:to:)`, which asks our views to draw into
/// a bitmap. Unlike `screencapture` it reads nothing from the screen, so it
/// needs no Screen Recording permission and works when driven over SSH.
@MainActor
public enum WindowSnapshotter {
    /// Renders `window`'s content, with any attached sheet (name prompts,
    /// alerts) drawn on top where it sits on screen.
    public static func image(of window: NSWindow) -> NSBitmapImageRep? {
        guard let content = window.contentView, let base = render(content) else { return nil }
        guard let sheet = window.attachedSheet, let sheetContent = sheet.contentView,
            let sheetImage = render(sheetContent)
        else { return base }

        let scale = CGFloat(base.pixelsWide) / max(content.bounds.width, 1)
        guard
            let canvas = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: base.pixelsWide,
                pixelsHigh: base.pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ), let context = NSGraphicsContext(bitmapImageRep: canvas)
        else { return base }

        // Both frames in screen coordinates (origin bottom-left), so the
        // sheet's offset inside the parent's content is a plain subtraction.
        let contentOnScreen = window.convertToScreen(content.convert(content.bounds, to: nil))
        let sheetOnScreen = sheet.convertToScreen(sheetContent.convert(sheetContent.bounds, to: nil))
        let sheetRect = CGRect(
            x: (sheetOnScreen.minX - contentOnScreen.minX) * scale,
            y: (sheetOnScreen.minY - contentOnScreen.minY) * scale,
            width: sheetOnScreen.width * scale,
            height: sheetOnScreen.height * scale
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none
        let full = CGRect(x: 0, y: 0, width: base.pixelsWide, height: base.pixelsHigh)
        base.draw(in: full)
        // Dim the parent the way a modal sheet visually separates from it.
        NSColor.black.withAlphaComponent(0.25).setFill()
        full.fill(using: .sourceOver)
        sheetImage.draw(in: sheetRect)
        NSColor.gray.setStroke()
        NSBezierPath(rect: sheetRect.insetBy(dx: -0.5, dy: -0.5)).stroke()
        NSGraphicsContext.restoreGraphicsState()
        return canvas
    }

    /// Writes a PNG of `window` to `url`, creating the folder if needed.
    public static func writePNG(of window: NSWindow, to url: URL) throws {
        guard let image = image(of: window), let data = image.representation(using: .png, properties: [:]) else {
            throw SnapshotError.renderFailed
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// The app's main content window (not a sheet, panel or menu).
    public static var mainWindow: NSWindow? {
        NSApp.windows.first { window in
            window.isVisible && !window.isSheet && !(window is NSPanel) && window.contentView != nil
                && window.className != "NSStatusBarWindow"
        }
    }

    private static func render(_ view: NSView) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }
}

/// Why a snapshot could not be taken.
public enum SnapshotError: Error, CustomStringConvertible {
    case noWindow
    case renderFailed

    public var description: String {
        switch self {
        case .noWindow: "There is no app window to photograph."
        case .renderFailed: "The window could not be drawn into a bitmap."
        }
    }
}
