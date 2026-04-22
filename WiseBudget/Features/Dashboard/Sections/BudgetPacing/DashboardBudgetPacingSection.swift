import SwiftUI

struct DashboardBudgetPacingSection: View {
    let daysRemainingInMonth: Int
    let dailyAllowance: Decimal
    let currency: String

    var body: some View {
        Section("Budget Pacing") {
            HStack {
                Label("Days Remaining", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(daysRemainingInMonth)")
                    .monospacedDigit()
            }
            HStack {
                Label("Daily Allowance", systemImage: "target")
                    .foregroundStyle(.orange)
                    .bold()
                Spacer()
                Text("\(dailyAllowance, format: .number.precision(.fractionLength(2))) \(currency)")
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
        }
    }
}
