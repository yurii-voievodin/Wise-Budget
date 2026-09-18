import SwiftUI

struct TransactionTransferRow: View {
    @Binding var isInternalTransfer: Bool

    var body: some View {
        HStack(spacing: Layout.Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer between my accounts")
                Text("Kept in history, but excluded from statistics and budgets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Layout.Spacing.medium)
            Toggle("Transfer between my accounts", isOn: $isInternalTransfer)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, Layout.Spacing.small)
    }
}
