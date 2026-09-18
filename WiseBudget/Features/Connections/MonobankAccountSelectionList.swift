import SwiftUI

struct MonobankAccountSelectionList: View {
    let accounts: [MonobankAccount]
    let selectedAccountIds: Set<String>
    let onToggle: (MonobankAccount) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small) {
            Text("Select which accounts to sync")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: Layout.Spacing.tight) {
                    ForEach(accounts) { account in
                        MonobankAccountRow(
                            account: account,
                            isSelected: selectedAccountIds.contains(account.id),
                            onToggle: { onToggle(account) }
                        )
                    }
                }
            }
        }
    }
}
