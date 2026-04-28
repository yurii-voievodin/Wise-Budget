import SwiftUI

struct DashboardEmptyStateView: View {
    let showGettingStartedActions: Bool
    let onAddExpense: () -> Void
    let onConnectBank: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No Data This Month", systemImage: "square.grid.2x2")
                .foregroundStyle(.secondary)
        } description: {
            Text(descriptionText)
        } actions: {
            if showGettingStartedActions {
                HStack(spacing: 12) {
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

    private var descriptionText: String {
        if showGettingStartedActions {
            return "Start by adding your first expense or connect a bank account to import transactions automatically."
        }

        return "Add expenses or income to see your monthly overview."
    }
}

#Preview {
    DashboardEmptyStateView(
        showGettingStartedActions: true,
        onAddExpense: {},
        onConnectBank: {}
    )
}
