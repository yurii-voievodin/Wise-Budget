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
                    .foregroundStyle(.income)
                Spacer()
                Text(amount: incomeDailyAverage, currency: currency)
                    .monospacedDigit()
                    .foregroundStyle(.income)
            }
            HStack {
                Label("Expenses", systemImage: "arrow.up.circle")
                    .foregroundStyle(.expense)
                Spacer()
                Text(amount: expenseDailyAverage, currency: currency)
                    .monospacedDigit()
                    .foregroundStyle(.expense)
            }
            HStack {
                Label("Balance", systemImage: dailyBalance >= .zero ? "checkmark.circle" : "exclamationmark.circle")
                    .bold()
                    .foregroundStyle(dailyBalance >= .zero ? .income : .expense)
                Spacer()
                Text(amount: dailyBalance, currency: currency, signed: true)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(dailyBalance >= .zero ? .income : .expense)
            }
        }
    }
}
