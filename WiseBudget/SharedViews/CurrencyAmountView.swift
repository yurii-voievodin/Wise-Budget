import SwiftUI

protocol CurrencyConvertible {
    var amount: Decimal { get }
    var currency: String { get }
    var baseCurrencyAmount: Decimal? { get }
    var baseCurrency: String? { get }
}

extension CurrencyConvertible {
    /// Returns the amount converted to the target currency, or nil if conversion is not possible.
    func convertedAmount(to targetCurrency: String) -> Decimal? {
        if currency == targetCurrency {
            return amount
        }
        if let baseAmount = baseCurrencyAmount,
           baseCurrency == targetCurrency {
            return baseAmount
        }
        return nil
    }
}

extension Array where Element: CurrencyConvertible {
    func filterForeignCurrency(defaultCurrency: String) -> [Element] {
        filter { item in
            item.currency != defaultCurrency
        }
    }
}

struct CurrencyAmountView: View {
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let item: CurrencyConvertible

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
