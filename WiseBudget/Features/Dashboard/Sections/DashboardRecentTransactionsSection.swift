import SwiftData
import SwiftUI

struct DashboardRecentTransaction: Identifiable {
    let id: PersistentIdentifier
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
                        TransactionRowView(
                            descriptionText: transaction.descriptionText ?? transaction.categoryName,
                            categoryName: transaction.descriptionText == nil ? nil : transaction.categoryName,
                            categoryIcon: transaction.descriptionText == nil ? nil : transaction.categoryIcon,
                            categoryColor: transaction.categoryName.map {
                                transaction.isExpense
                                    ? DefaultExpenseCategory.color(for: $0)
                                    : DefaultIncomeCategory.color(for: $0)
                            },
                            extraField: transaction.date.formatted(.dateTime.day().month(.abbreviated)),
                            item: transaction.item,
                            amountTintColor: transaction.isExpense ? .expense : .income
                        )
                        .accessibilityLabel(transaction.isExpense ? "Expense" : "Income")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
