import SwiftUI

struct DashboardEmptyStateView: View {
    enum State {
        case onboarding
        case noTransactionsThisMonth
    }

    let state: State
    let onAddExpense: () -> Void
    let onConnectBank: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
        } description: {
            Text(description)
        } actions: {
            if state == .onboarding {
                HStack(spacing: Layout.Spacing.medium) {
                    Button(action: onConnectBank) {
                        Label("Connect Bank", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onAddExpense) {
                        Label("Add Expense", systemImage: "plus")
                    }
                }
            } else {
                HStack(spacing: Layout.Spacing.medium) {
                    Button(action: onAddExpense) {
                        Label("Add Expense", systemImage: "plus")
                    }

                    Button(action: onConnectBank) {
                        Label("Connect Bank", systemImage: "link")
                    }
                }
            }
        }
    }

    private var title: String {
        switch state {
        case .onboarding:
            "Connect Your First Bank"
        case .noTransactionsThisMonth:
            "No Data This Month"
        }
    }

    private var systemImage: String {
        switch state {
        case .onboarding:
            "link.badge.plus"
        case .noTransactionsThisMonth:
            "square.grid.2x2"
        }
    }

    private var description: String {
        switch state {
        case .onboarding:
            "Connect a bank account to import transactions automatically and start building your dashboard."
        case .noTransactionsThisMonth:
            "Add expenses or income to see your monthly overview."
        }
    }
}

#Preview {
    DashboardEmptyStateView(
        state: .onboarding,
        onAddExpense: {},
        onConnectBank: {}
    )
}

#Preview("No Transactions This Month") {
    DashboardEmptyStateView(
        state: .noTransactionsThisMonth,
        onAddExpense: {},
        onConnectBank: {}
    )
}
