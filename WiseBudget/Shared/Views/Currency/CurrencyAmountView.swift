import SwiftUI

struct CurrencyAmountView: View {
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let item: CurrencyConvertible
    var tintColor: Color?

    var body: some View {
        VStack(alignment: .trailing) {
            HStack(spacing: 4) {
                Text(item.amount, format: .number)
                    .font(.headline)
                    .foregroundStyle(tintColor ?? .primary)
                Text(item.currency)
                    .font(.headline)
                    .foregroundStyle(item.currency == defaultCurrency ? (tintColor ?? .primary) : .secondary)
            }
            if let baseAmount = item.baseCurrencyAmount,
               let baseCur = item.baseCurrency {
                HStack(spacing: 4) {
                    Text(baseAmount, format: .number)
                    Text(baseCur)
                }
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
    var isInternalTransfer: Bool = false
}

#Preview("Currency Amount") {
    VStack(alignment: .trailing, spacing: 16) {
        CurrencyAmountView(item: PreviewItem(amount: 52.30, currency: "EUR", baseCurrencyAmount: nil, baseCurrency: nil))
        CurrencyAmountView(item: PreviewItem(amount: 800, currency: "USD", baseCurrencyAmount: 740, baseCurrency: "EUR"))
        CurrencyAmountView(item: PreviewItem(amount: 15, currency: "GBP", baseCurrencyAmount: 17.50, baseCurrency: "EUR"))
    }
    .padding()
}
