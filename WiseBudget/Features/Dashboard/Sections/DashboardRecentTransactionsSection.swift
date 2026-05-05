import SwiftUI

struct DashboardRecentTransaction: Identifiable {
    let id = UUID()
    let descriptionText: String?
    let categoryName: String?
    let categoryIcon: String?
    let item: CurrencyConvertible
    let isExpense: Bool
    let date: Date
}

struct DashboardRecentTransactionsSection: View {
    let transactions: [DashboardRecentTransaction]
    let onTap: (DashboardRecentTransaction) -> Void

    var body: some View {
        Section("Recent Transactions") {
            if transactions.isEmpty {
                Text("No transactions this month")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(transactions) { transaction in
                    Button {
                        onTap(transaction)
                    } label: {
                        HStack {
                            Image(systemName: transaction.isExpense ? "arrow.up.circle" : "arrow.down.circle")
                                .foregroundStyle(transaction.isExpense ? .expense : .income)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            TransactionRowView(
                                descriptionText: transaction.descriptionText,
                                categoryName: transaction.categoryName,
                                categoryIcon: transaction.categoryIcon,
                                categoryColor: transaction.categoryName.map {
                                    transaction.isExpense
                                        ? DefaultExpenseCategory.color(for: $0)
                                        : DefaultIncomeCategory.color(for: $0)
                                },
                                extraField: nil,
                                item: transaction.item
                            )
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
