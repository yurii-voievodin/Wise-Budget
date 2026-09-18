import SwiftUI

struct MonthCashflowCard: View {
    let totals: MonthlyTotals
    let currency: String

    private var scale: Decimal { max(totals.income, totals.expenses) }

    private var savingsRate: Double? {
        guard totals.income > 0 else { return nil }
        return NSDecimalNumber(decimal: totals.balance / totals.income).doubleValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(totals.month.fullLabel)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.secondary)
                Spacer()
                if let savingsRate {
                    Text("\(savingsRate * 100, format: .number.precision(.fractionLength(0)))% saved")
                        .font(.caption)
                        .foregroundStyle(savingsRate >= 0 ? Color.income : Color.expense)
                }
            }

            CashflowBarRow(
                label: "Income",
                amount: totals.income,
                maxValue: scale,
                tint: .income,
                currency: currency
            )
            CashflowBarRow(
                label: "Expenses",
                amount: totals.expenses,
                maxValue: scale,
                tint: .expense,
                currency: currency
            )

            Divider()

            LabeledContent("Balance") {
                Text(amount: totals.balance, currency: currency, signed: true, precision: 0)
                    .monospacedDigit()
                    .bold()
                    .foregroundStyle(totals.balance >= .zero ? .income : .expense)
            }
            .foregroundStyle(.secondary)
        }
        .padding(Layout.Spacing.medium)
        .cardBackground()
    }
}
