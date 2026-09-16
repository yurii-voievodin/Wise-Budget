import SwiftUI

struct CashflowStatGrid: View {
    let income: Decimal
    let expenses: Decimal
    let balance: Decimal
    let currency: String

    private let columns = [
        GridItem(.flexible(), spacing: Layout.Spacing.medium),
        GridItem(.flexible(), spacing: Layout.Spacing.medium),
        GridItem(.flexible(), spacing: Layout.Spacing.medium)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Layout.Spacing.medium) {
            StatCard(
                label: "Income",
                icon: "arrow.down.circle.fill",
                color: .income,
                amount: income,
                currency: currency,
                bold: true,
                precision: 0
            )
            StatCard(
                label: "Expenses",
                icon: "arrow.up.circle.fill",
                color: .expense,
                amount: expenses,
                currency: currency,
                bold: true,
                precision: 0
            )
            StatCard(
                label: "Balance",
                icon: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                color: balance >= .zero ? .income : .expense,
                amount: balance,
                currency: currency,
                signed: true,
                bold: true,
                precision: 0
            )
        }
    }
}
