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
                    currency: currency,
                    subtitle: dailyLabel(amount: incomeDailyAverage)
                )
                StatCard(
                    label: "Expenses",
                    icon: "arrow.up.circle.fill",
                    color: .expense,
                    amount: totalExpenses,
                    currency: currency,
                    subtitle: dailyLabel(amount: expenseDailyAverage)
                )
                StatCard(
                    label: "Balance",
                    icon: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    color: balance >= .zero ? .income : .expense,
                    amount: balance,
                    currency: currency,
                    signed: true,
                    bold: true,
                    subtitle: dailyLabel(amount: dailyBalance, signed: true)
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func dailyLabel(amount: Decimal, signed: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        if signed { formatter.positivePrefix = "+" }
        let raw = formatter.string(from: amount as NSDecimalNumber) ?? ""
        return "\(raw) \(currency) / day"
    }
}
