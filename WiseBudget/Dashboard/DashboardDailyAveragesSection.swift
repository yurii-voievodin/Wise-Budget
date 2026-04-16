import SwiftUI

struct DashboardDailyAveragesSection: View {
    let incomeDailyAverage: Decimal
    let expenseDailyAverage: Decimal
    let dailyBalance: Decimal
    let currency: String

    var body: some View {
        Section("Daily Averages") {
            HStack {
                Label("Income", systemImage: "arrow.down.circle")
                    .foregroundStyle(.green)
                Spacer()
                Text("\(incomeDailyAverage, format: .number.precision(.fractionLength(2))) \(currency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            HStack {
                Label("Expenses", systemImage: "arrow.up.circle")
                    .foregroundStyle(.red)
                Spacer()
                Text("\(expenseDailyAverage, format: .number.precision(.fractionLength(2))) \(currency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            HStack {
                Label("Balance", systemImage: dailyBalance >= .zero ? "checkmark.circle" : "exclamationmark.circle")
                    .bold()
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
                Spacer()
                Text("\(dailyBalance >= .zero ? "+" : "")\(dailyBalance, format: .number.precision(.fractionLength(2))) \(currency)")
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
            }
        }
    }
}
