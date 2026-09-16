import SwiftUI

struct TransactionEmptyStateView: View {
    let title: String
    let systemImage: String
    let addLabel: String
    let onAdd: () -> Void
    let onNavigateToBank: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text("Add your first entry, import from a CSV file,\nor connect a bank account to get started.")
        } actions: {
            HStack(spacing: Layout.Spacing.medium) {
                Button(action: onAdd) {
                    Label(addLabel, systemImage: "plus")
                }
                Button(action: onNavigateToBank) {
                    Label("Connect Bank", systemImage: "link")
                }
            }
        }
    }
}
