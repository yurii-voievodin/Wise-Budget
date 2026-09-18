import SwiftUI

struct ExpenseCalendarDayCellView: View {
    let day: Int
    let isToday: Bool
    let defaultCurrency: String
    let currencyTotals: [String: Decimal]
    let backgroundColor: Color
    let backgroundOpacity: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.caption)
                .bold()
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 24, height: 24)
                .background {
                    if isToday {
                        Circle().fill(.blue)
                    }
                }

            if !currencyTotals.isEmpty {
                ForEach(currencyTotals.sortedWithDefaultFirst(defaultCurrency), id: \.key) { currency, amount in
                    Text("\(formattedCalendarAmount(amount)) \(currency)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .background {
            RoundedRectangle(cornerRadius: Layout.Radius.small)
                .fill(backgroundColor.opacity(backgroundOpacity))
        }
    }

}

#Preview {
    HStack(spacing: Layout.Spacing.tight) {
        ExpenseCalendarDayCellView(
            day: 1, isToday: false, defaultCurrency: "USD",
            currencyTotals: [:], backgroundColor: .income, backgroundOpacity: 0.06
        )
        ExpenseCalendarDayCellView(
            day: 15, isToday: true, defaultCurrency: "USD",
            currencyTotals: ["USD": 42], backgroundColor: .yellow, backgroundOpacity: 0.2
        )
        ExpenseCalendarDayCellView(
            day: 28, isToday: false, defaultCurrency: "USD",
            currencyTotals: ["USD": 250, "EUR": 30], backgroundColor: .expense, backgroundOpacity: 0.3
        )
    }
    .padding()
    .frame(width: 300)
}
