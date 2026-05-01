import SwiftUI

struct ExpenseComparisonBreakdownSection: View {
    let monthTotals: [(month: MonthKey, total: Double)]
    let currency: String

    var body: some View {
        Section("Monthly Totals") {
            ForEach(monthTotals.filter { $0.total > 0 }, id: \.month) { item in
                LabeledContent(item.month.fullLabel) {
                    Text("\(Decimal(item.total), format: .number.precision(.fractionLength(0))) \(currency)")
                        .monospacedDigit()
                }
            }
        }
    }
}
