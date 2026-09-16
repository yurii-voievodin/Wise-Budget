import SwiftUI

struct MonobankAccountSelectionView: View {
    let connectedName: String
    let accounts: [MonobankAccount]
    @Binding var selectedAccountIds: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connected as \(connectedName)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)

            Divider()

            Text("Select accounts to sync")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: Layout.Spacing.tight) {
                    ForEach(accounts) { account in
                        MonobankAccountRow(
                            account: account,
                            isSelected: selectedAccountIds.contains(account.id),
                            onToggle: { toggle(account) }
                        )
                    }
                }
            }
        }
    }

    private func toggle(_ account: MonobankAccount) {
        if selectedAccountIds.contains(account.id) {
            selectedAccountIds.remove(account.id)
        } else {
            selectedAccountIds.insert(account.id)
        }
    }
}
