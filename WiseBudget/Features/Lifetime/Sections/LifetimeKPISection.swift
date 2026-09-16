import SwiftUI

struct LifetimeKPISection: View {
    let totalIncome: Double
    let totalExpenses: Double
    let net: Double
    let span: String
    let currency: String

    var body: some View {
        Section("Lifetime Totals") {
            HStack(alignment: .top, spacing: Layout.Spacing.large) {
                kpi("Income", value: totalIncome, color: .income)
                kpi("Expenses", value: totalExpenses, color: .expense)
                kpi("Net", value: net, color: net >= 0 ? .income : .expense)
                VStack(alignment: .leading, spacing: Layout.Spacing.tight) {
                    Text("Time span")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(span)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, Layout.Spacing.tight)
        }
    }

    private func kpi(_ title: LocalizedStringKey, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.tight) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(amount: Decimal(value), currency: currency, precision: 0)
                .font(.title3.bold())
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
