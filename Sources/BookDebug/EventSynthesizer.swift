import AppKit

/// Feeds synthesized mouse and keyboard events into our own app, the same way
/// the window server would deliver real ones.
///
/// Events go through `NSApp.sendEvent`, so they meet the real hit testing,
/// first responder, key equivalents and text input of the running app. They
/// never leave the process, so no Accessibility permission is needed.
@MainActor
enum EventSynthesizer {
    /// A named key with its virtual key code and the characters it produces.
    struct Key {
        let code: UInt16
        let characters: String

        static let named: [String: Key] = [
            "return": Key(code: 36, characters: "\r"),
            "enter": Key(code: 76, characters: "\u{3}"),
            "escape": Key(code: 53, characters: "\u{1b}"),
            "tab": Key(code: 48, characters: "\t"),
            "delete": Key(code: 51, characters: "\u{7f}"),
            "left": Key(code: 123, characters: "\u{F702}"),
            "right": Key(code: 124, characters: "\u{F703}"),
            "up": Key(code: 126, characters: "\u{F700}"),
            "down": Key(code: 125, characters: "\u{F701}"),
            "[": Key(code: 33, characters: "["),
            "]": Key(code: 30, characters: "]"),
            "n": Key(code: 45, characters: "n"),
            "a": Key(code: 0, characters: "a"),
            "q": Key(code: 12, characters: "q"),
        ]
    }

    /// Clicks at `point`, given in the coordinate space SwiftUI calls `.global`
    /// for `window`.
    static func click(at point: CGPoint, in window: NSWindow, button: MouseButton = .left) {
        let location = windowLocation(of: point, in: window)
        let (down, up) = button.eventTypes
        for type in [down, up] {
            guard
                let event = NSEvent.mouseEvent(
                    with: type,
                    location: location,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: type == up ? 0 : 1
                )
            else { continue }
            NSApp.sendEvent(event)
        }
    }

    /// Types `text` one character at a time, as key presses.
    static func type(_ text: String, in window: NSWindow) {
        for character in text {
            let string = character == "\n" ? "\r" : String(character)
            let code: UInt16 = character == "\n" ? 36 : 0
            press(Key(code: code, characters: string), modifiers: [], in: window)
        }
    }

    /// Presses a key, optionally with modifiers (e.g. ⌘]).
    static func press(_ key: Key, modifiers: NSEvent.ModifierFlags, in window: NSWindow) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            guard
                let event = NSEvent.keyEvent(
                    with: type,
                    location: .zero,
                    modifierFlags: modifiers,
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    characters: key.characters,
                    charactersIgnoringModifiers: key.characters,
                    isARepeat: false,
                    keyCode: key.code
                )
            else { continue }
            NSApp.sendEvent(event)
        }
    }

    enum MouseButton {
        case left, right

        var eventTypes: (NSEvent.EventType, NSEvent.EventType) {
            switch self {
            case .left: (.leftMouseDown, .leftMouseUp)
            case .right: (.rightMouseDown, .rightMouseUp)
            }
        }
    }

    /// SwiftUI's `.global` space on macOS starts at the window's top-left
    /// corner (title bar included); AppKit's window space starts bottom-left.
    static func windowLocation(of point: CGPoint, in window: NSWindow) -> NSPoint {
        NSPoint(x: point.x, y: window.frame.height - point.y)
    }
}
