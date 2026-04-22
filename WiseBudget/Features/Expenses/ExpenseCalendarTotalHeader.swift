import SwiftUI

struct ExpenseCalendarTotalHeader: View {
    let totals: [String: Decimal]
    let defaultCurrency: String

    private var sortedTotals: [(key: String, value: Decimal)] {
        totals.sorted { a, b in
            if a.key == defaultCurrency { return true }
            if b.key == defaultCurrency { return false }
            return a.key < b.key
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Month Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(sortedTotals, id: \.key) { currency, total in
                Text("\(ExpenseCalendarDayCellView.formattedAmount(total)) \(currency)")
                    .font(currency == defaultCurrency ? .title2 : .headline)
                    .bold()
                    .foregroundStyle(currency == defaultCurrency ? .primary : .secondary)
            }
        }
    }
}
