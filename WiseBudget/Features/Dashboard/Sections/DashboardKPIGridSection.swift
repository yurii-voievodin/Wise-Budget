import SwiftUI

struct DashboardKPIGridSection: View {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let balance: Decimal
    let incomeDailyAverage: Decimal
    let expenseDailyAverage: Decimal
    let dailyBalance: Decimal
    let currency: String

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 12) {
                StatCard(
                    label: "Income",
                    icon: "arrow.down.circle.fill",
                    color: .income,
                    amount: totalIncome,
                    currency: currency
                )
                StatCard(
                    label: "Expenses",
                    icon: "arrow.up.circle.fill",
                    color: .expense,
                    amount: totalExpenses,
                    currency: currency
                )
                StatCard(
                    label: "Balance",
                    icon: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    color: balance >= .zero ? .income : .expense,
                    amount: balance,
                    currency: currency,
                    signed: true,
                    bold: true
                )
                StatCard(
                    label: "Daily Income",
                    icon: "arrow.down.circle",
                    color: .income,
                    amount: incomeDailyAverage,
                    currency: currency
                )
                StatCard(
                    label: "Daily Expenses",
                    icon: "arrow.up.circle",
                    color: .expense,
                    amount: expenseDailyAverage,
                    currency: currency
                )
                StatCard(
                    label: "Daily Balance",
                    icon: dailyBalance >= .zero ? "checkmark.circle" : "exclamationmark.circle",
                    color: dailyBalance >= .zero ? .income : .expense,
                    amount: dailyBalance,
                    currency: currency,
                    signed: true,
                    bold: true
                )
            }
            .padding(.vertical, 4)
        }
    }
}
