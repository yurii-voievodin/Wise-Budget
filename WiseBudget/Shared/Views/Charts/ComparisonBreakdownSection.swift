import SwiftUI

struct ComparisonBreakdownSection: View {
    let monthTotals: [(month: MonthKey, total: Double)]
    let currency: String
    var onSelect: ((MonthKey) -> Void)? = nil

    var body: some View {
        Section("Monthly Totals") {
            ForEach(monthTotals.filter { $0.total > 0 }, id: \.month) { item in
                if let onSelect {
                    Button {
                        onSelect(item.month)
                    } label: {
                        row(for: item)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                } else {
                    row(for: item)
                }
            }
        }
    }

    private func row(for item: (month: MonthKey, total: Double)) -> some View {
        LabeledContent(item.month.fullLabel) {
            Text(amount: Decimal(item.total), currency: currency, precision: 0)
                .monospacedDigit()
        }
    }
}
