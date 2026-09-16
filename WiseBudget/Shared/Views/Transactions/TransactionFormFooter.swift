import SwiftUI

struct TransactionFormFooter: View {
    let isEditing: Bool
    let isSaveDisabled: Bool
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: Layout.Spacing.medium) {
            Spacer()
            Button("Cancel", action: cancel)
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add", action: onSave)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
        }
        .controlSize(.large)
        .padding(.horizontal, Layout.Spacing.xLarge)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private func cancel() {
        dismiss()
    }
}
