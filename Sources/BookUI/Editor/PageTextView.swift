import AppKit
import BookCore
import SwiftUI

/// The writable page: an AppKit text view whose every edit is vetted by the
/// editor view model (256 characters, 14 wrapped lines).
///
/// As a second safety net, after AppKit applies an edit the rendered line
/// count is checked; an edit that would draw a 15th line is reverted.
struct PageTextView: NSViewRepresentable {
    let model: BookEditorViewModel
    let scale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSTextView {
        let textView = Self.makePageTextView(scale: scale)
        textView.string = model.currentText
        textView.isEditable = model.isEditable
        textView.delegate = context.coordinator
        context.coordinator.lastAccepted = model.currentText
        textView.takesFocusWhenShown = model.isEditable
        return textView
    }

    /// A text view with the page's typography and options (no smart
    /// substitutions, fixed 114 px container). Shared with rendering tests so
    /// they draw exactly what the editor draws.
    static func makePageTextView(scale: CGFloat) -> PageNSTextView {
        let storage = NSTextStorage()
        let layoutManager = PageLayoutManager(scale: scale)
        let container = NSTextContainer()
        PageTextLayout.configure(container, scale: scale)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let textView = PageNSTextView(frame: .zero, textContainer: container)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.textContainerInset = .zero
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.focusRingType = .none
        textView.insertionPointColor = .black
        textView.typingAttributes = PageTextLayout.attributes(scale: scale)
        textView.selectedTextAttributes = [.backgroundColor: NSColor(white: 0, alpha: 0.2)]
        textView.isSelectable = true
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.isEditable = model.isEditable
        if textView.string != model.currentText {
            textView.string = model.currentText
            context.coordinator.lastAccepted = model.currentText
        }
        textView.typingAttributes = PageTextLayout.attributes(scale: scale)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: BookEditorViewModel
        /// The last text known to fit, restored if AppKit renders too many lines.
        var lastAccepted = ""

        init(model: BookEditorViewModel) {
            self.model = model
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            // Attribute-only changes carry no string.
            guard let replacement = replacementString else { return true }
            // Let input methods compose freely; the result is vetted on commit.
            if textView.hasMarkedText() { return true }

            let before = textView.string
            guard let accepted = model.applyEdit(replacing: affectedCharRange, with: replacement) else {
                NSSound.beep()
                return false
            }
            let naive = (before as NSString).replacingCharacters(in: affectedCharRange, with: replacement)
            if accepted == naive {
                return true
            }
            // The edit was clipped (long paste) or sanitised: apply it ourselves.
            textView.string = accepted
            let caret = min(
                affectedCharRange.location + (accepted as NSString).length - (before as NSString).length + affectedCharRange.length,
                (accepted as NSString).length
            )
            textView.setSelectedRange(NSRange(location: max(caret, 0), length: 0))
            lastAccepted = accepted
            if accepted.count < naive.count {
                NSSound.beep()
            }
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                let layoutManager = textView.layoutManager,
                let container = textView.textContainer,
                !textView.hasMarkedText()
            else { return }
            let rendered = PageTextLayout.renderedLineCount(in: layoutManager, container: container)
            if rendered > BookLimits.linesPerPage || !model.setCurrentTextIfChanged(textView.string) {
                textView.string = lastAccepted
                model.setCurrentTextIfChanged(lastAccepted)
                NSSound.beep()
                return
            }
            lastAccepted = textView.string
        }
    }
}

extension BookEditorViewModel {
    /// Commits text the text view already shows; a no-op when it matches the model.
    @discardableResult
    func setCurrentTextIfChanged(_ text: String) -> Bool {
        text == currentText || setCurrentText(text)
    }
}

/// The page's text view. It takes keyboard focus, caret at the end, as soon as
/// it is in a window, so a book opens ready to type.
///
/// Focus is requested from `viewDidMoveToWindow` rather than from the
/// representable's `makeNSView`, because the view has no window yet there, and
/// retried on the next run-loop turn because a closing sheet (the new-book
/// title prompt) hands focus back to the window as it goes away.
final class PageNSTextView: NSTextView {
    var takesFocusWhenShown = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard takesFocusWhenShown, window != nil else { return }
        takeFocus()
        DispatchQueue.main.async { [weak self] in self?.takeFocus() }
    }

    private func takeFocus() {
        guard let window, window.firstResponder !== self else { return }
        window.makeFirstResponder(self)
        setSelectedRange(NSRange(location: (string as NSString).length, length: 0))
    }
}
