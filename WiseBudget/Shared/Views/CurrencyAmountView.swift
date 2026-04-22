import SwiftUI

struct CurrencyAmountView: View {
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let item: CurrencyConvertible
    var tintColor: Color?

    var body: some View {
        VStack(alignment: .trailing) {
            HStack(spacing: 4) {
                if item.currency != defaultCurrency {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text("\(item.amount, format: .number) \(item.currency)")
                    .font(.headline)
                    .foregroundStyle(tintColor ?? .primary)
            }
            if let baseAmount = item.baseCurrencyAmount,
               let baseCur = item.baseCurrency {
                Text("\(baseAmount, format: .number) \(baseCur)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PreviewItem: CurrencyConvertible {
    var amount: Decimal
    var currency: String
    var baseCurrencyAmount: Decimal?
    var baseCurrency: String?
}

#Preview("Currency Amount") {
    VStack(alignment: .trailing, spacing: 16) {
        CurrencyAmountView(item: PreviewItem(amount: 52.30, currency: "EUR", baseCurrencyAmount: nil, baseCurrency: nil))
        CurrencyAmountView(item: PreviewItem(amount: 800, currency: "USD", baseCurrencyAmount: 740, baseCurrency: "EUR"))
        CurrencyAmountView(item: PreviewItem(amount: 15, currency: "GBP", baseCurrencyAmount: 17.50, baseCurrency: "EUR"))
    }
    .padding()
}
