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
                KPICell(
                    label: "Income",
                    icon: "arrow.down.circle.fill",
                    color: .income,
                    amount: totalIncome,
                    currency: currency
                )
                KPICell(
                    label: "Expenses",
                    icon: "arrow.up.circle.fill",
                    color: .expense,
                    amount: totalExpenses,
                    currency: currency
                )
                KPICell(
                    label: "Balance",
                    icon: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    color: balance >= .zero ? .income : .expense,
                    amount: balance,
                    currency: currency,
                    signed: true,
                    bold: true
                )
                KPICell(
                    label: "Daily Income",
                    icon: "arrow.down.circle",
                    color: .income,
                    amount: incomeDailyAverage,
                    currency: currency
                )
                KPICell(
                    label: "Daily Expenses",
                    icon: "arrow.up.circle",
                    color: .expense,
                    amount: expenseDailyAverage,
                    currency: currency
                )
                KPICell(
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

private struct KPICell: View {
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    let amount: Decimal
    let currency: String
    var signed: Bool = false
    var bold: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .lineLimit(1)
            Text(amount: amount, currency: currency, signed: signed)
                .font(.title3)
                .monospacedDigit()
                .bold(bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
