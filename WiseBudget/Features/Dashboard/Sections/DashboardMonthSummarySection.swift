import SwiftUI

struct DashboardMonthSummarySection: View {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let balance: Decimal
    let currency: String

    var body: some View {
        Section("Month Summary") {
            HStack {
                Label("Income", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.income)
                Spacer()
                Text("\(totalIncome, format: .number.precision(.fractionLength(2))) \(currency)")
                    .monospacedDigit()
                    .foregroundStyle(.income)
            }
            HStack {
                Label("Expenses", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.expense)
                Spacer()
                Text("\(totalExpenses, format: .number.precision(.fractionLength(2))) \(currency)")
                    .monospacedDigit()
                    .foregroundStyle(.expense)
            }
            HStack {
                Label("Balance", systemImage: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .bold()
                    .foregroundStyle(balance >= .zero ? .income : .expense)
                Spacer()
                Text("\(balance >= .zero ? "+" : "")\(balance, format: .number.precision(.fractionLength(2))) \(currency)")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(balance >= .zero ? .income : .expense)
            }
        }
    }
}
