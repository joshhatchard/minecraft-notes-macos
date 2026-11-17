import SwiftUI

/// A pending destructive action awaiting confirmation.
struct DeletionRequest: Identifiable {
    let id = UUID()
    /// Question shown to the user, e.g. "Delete the shelf “Maths”?".
    let title: String
    /// Explanation of what will be lost.
    let message: String
    /// Performs the deletion.
    let perform: () -> Void
}

extension View {
    /// Shows a confirmation alert for `request` with a destructive Delete button.
    func deletionConfirmation(_ request: Binding<DeletionRequest?>) -> some View {
        alert(
            request.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { request.wrappedValue != nil },
                set: { if !$0 { request.wrappedValue = nil } }
            ),
            presenting: request.wrappedValue
        ) { pending in
            Button("Delete", role: .destructive, action: pending.perform)
            Button("Cancel", role: .cancel) {}
        } message: { pending in
            Text(pending.message)
        }
    }

    /// Shows `message` in an alert while it is non-nil.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
