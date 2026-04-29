import Foundation

nonisolated protocol CurrencyConvertible {
    var amount: Decimal { get }
    var currency: String { get }
    var baseCurrencyAmount: Decimal? { get }
    var baseCurrency: String? { get }
    /// Internal transfers stay visible in history but are excluded from
    /// every aggregation (totals, charts, budgets, AI insights, day totals).
    var isInternalTransfer: Bool { get }
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
