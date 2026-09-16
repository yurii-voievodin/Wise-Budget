import SwiftUI

struct ExpenseCalendarTotalHeader: View {
    let totals: [String: Decimal]
    let defaultCurrency: String

    var body: some View {
        VStack(spacing: Layout.Spacing.tight) {
            Text("Month Total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(totals.sortedWithDefaultFirst(defaultCurrency), id: \.key) { currency, total in
                Text("\(formattedCalendarAmount(total)) \(currency)")
                    .font(currency == defaultCurrency ? .title2 : .headline)
                    .bold()
                    .foregroundStyle(currency == defaultCurrency ? .primary : .secondary)
            }
        }
    }
}
