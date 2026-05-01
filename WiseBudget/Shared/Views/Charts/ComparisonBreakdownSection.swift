import SwiftUI

struct ComparisonBreakdownSection: View {
    let monthTotals: [(month: MonthKey, total: Double)]
    let currency: String

    var body: some View {
        Section("Monthly Totals") {
            ForEach(monthTotals.filter { $0.total > 0 }, id: \.month) { item in
                LabeledContent(item.month.fullLabel) {
                    Text(amount: Decimal(item.total), currency: currency, precision: 0)
                        .monospacedDigit()
                }
            }
        }
    }
}
