import SwiftUI

/// A request to type a name (create or rename), shown as a sheet.
struct NamePrompt: Identifiable {
    let id = UUID()
    /// Heading, e.g. "New Chest".
    let title: String
    /// Text the field starts with.
    var initialName = ""
    /// Label of the confirming button.
    var confirmTitle = "Done"
    /// Maximum length accepted by the field.
    let maxLength: Int
    /// Performs the action. Returns an error message to show, or `nil` on success.
    let submit: (String) -> String?
}

/// Sheet with a Minecraft-style text box for naming chests, shelves and books.
struct NamePromptSheet: View {
    let prompt: NamePrompt
    @State private var name: String
    @State private var error: String?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private let scale = PixelTheme.guiScale

    init(prompt: NamePrompt) {
        self.prompt = prompt
        _name = State(initialValue: prompt.initialName)
    }

    var body: some View {
        VStack(spacing: 8 * scale) {
            PixelText(prompt.title, color: PixelTheme.title)
            PixelTextField(text: $name, maxLength: prompt.maxLength, scale: scale)
                .focused($focused)
                .onSubmit(confirm)
                .frame(width: 200 * scale)
            if let error {
                PixelText(error, color: Color(red: 1, green: 0.33, blue: 0.33))
                    .frame(width: 200 * scale)
            }
            HStack(spacing: 4 * scale) {
                PixelButton(title: prompt.confirmTitle, width: 98, action: confirm)
                    .keyboardShortcut(.defaultAction)
                PixelButton(title: "Cancel", width: 98) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(12 * scale)
        .background(TiledBackground(texture: .darkOakPlanks))
        .onAppear { focused = true }
    }

    private func confirm() {
        if let message = prompt.submit(name) {
            error = message
        } else {
            dismiss()
        }
    }
}

/// A Minecraft edit box: black fill, grey border, pixel font, length-limited.
struct PixelTextField: View {
    @Binding var text: String
    let maxLength: Int
    var scale: CGFloat = PixelTheme.guiScale
    var alignment: TextAlignment = .leading
    var ink: Color = PixelTheme.text
    var framed = true

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(PixelTheme.font(scale: scale))
            .foregroundStyle(ink)
            .multilineTextAlignment(alignment)
            .padding(.horizontal, 4 * scale)
            .frame(height: 20 * scale)
            .background(framed ? PixelTheme.fieldFill : .clear)
            .overlay {
                if framed {
                    Rectangle().strokeBorder(PixelTheme.fieldBorder, lineWidth: scale)
                }
            }
            .onChange(of: text) { _, newValue in
                let clean = newValue.filter { !$0.isNewline }
                let limited = String(clean.prefix(maxLength))
                if limited != newValue {
                    text = limited
                }
            }
    }
}
