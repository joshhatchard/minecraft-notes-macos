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
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer()
        PageTextLayout.configure(container, scale: scale)
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let textView = NSTextView(frame: .zero, textContainer: container)
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
        textView.string = model.currentText
        textView.isEditable = model.isEditable
        textView.isSelectable = true
        textView.delegate = context.coordinator
        context.coordinator.lastAccepted = model.currentText
        if model.isEditable {
            DispatchQueue.main.async { [weak textView] in
                guard let textView else { return }
                textView.window?.makeFirstResponder(textView)
                textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            }
        }
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
