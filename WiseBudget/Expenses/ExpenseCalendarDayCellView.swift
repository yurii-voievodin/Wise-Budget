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
                .fontWeight(.bold)
                .foregroundStyle(isToday ? .white : .primary)
                .frame(width: 24, height: 24)
                .background {
                    if isToday {
                        Circle().fill(.blue)
                    }
                }

            if !currencyTotals.isEmpty {
                let sorted = currencyTotals.sorted { a, b in
                    if a.key == defaultCurrency { return true }
                    if b.key == defaultCurrency { return false }
                    return a.key < b.key
                }
                ForEach(sorted, id: \.key) { currency, amount in
                    Text("\(Self.formattedAmount(amount)) \(currency)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor.opacity(backgroundOpacity))
        )
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func formattedAmount(_ value: Decimal) -> String {
        amountFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

#Preview {
    HStack(spacing: 4) {
        ExpenseCalendarDayCellView(
            day: 1, isToday: false, defaultCurrency: "USD",
            currencyTotals: [:], backgroundColor: .green, backgroundOpacity: 0.06
        )
        ExpenseCalendarDayCellView(
            day: 15, isToday: true, defaultCurrency: "USD",
            currencyTotals: ["USD": 42], backgroundColor: .yellow, backgroundOpacity: 0.2
        )
        ExpenseCalendarDayCellView(
            day: 28, isToday: false, defaultCurrency: "USD",
            currencyTotals: ["USD": 250, "EUR": 30], backgroundColor: .red, backgroundOpacity: 0.3
        )
    }
    .padding()
    .frame(width: 300)
}
