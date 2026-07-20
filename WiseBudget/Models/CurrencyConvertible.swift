import Foundation

nonisolated protocol CurrencyConvertible {
    var amount: Decimal { get }
    var currency: String { get }
    var baseCurrencyAmount: Decimal? { get }
    var baseCurrency: String? { get }
    /// Internal transfers stay visible in history but are excluded from
    /// every aggregation (totals, charts, budgets, AI insights, day totals).
    var isInternalTransfer: Bool { get }
    /// Set by sync services (`wise_*`, `mono_*`); `nil` for manual or CSV imports.
    var externalId: String? { get }
}

extension CurrencyConvertible {
    var externalId: String? { nil }
}

nonisolated enum TransactionSource: Hashable {
    case manualOrCSV
    case wiseSync
    case monobankSync

    static let wisePrefix = "wise_"
    static let monobankPrefix = "mono_"

    init(externalId: String?) {
        guard let id = externalId else { self = .manualOrCSV; return }
        if id.hasPrefix(Self.wisePrefix) { self = .wiseSync }
        else if id.hasPrefix(Self.monobankPrefix) { self = .monobankSync }
        else { self = .manualOrCSV }
    }

    var isSynced: Bool { self != .manualOrCSV }
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

    func filterBySource(_ sourceFilter: TransactionSourceFilter) -> [Element] {
        switch sourceFilter {
        case .all:
            return self
        case .syncedOnly:
            return filter { TransactionSource(externalId: $0.externalId).isSynced }
        case .manualOnly:
            return filter { !TransactionSource(externalId: $0.externalId).isSynced }
        }
    }

    func filterBySearchText(
        _ text: String,
        descriptionText: (Element) -> String?,
        categoryName: (Element) -> String?,
        extraField: (Element) -> String?
    ) -> [Element] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        let needle = trimmed.lowercased()
        return filter { item in
            if descriptionText(item)?.lowercased().contains(needle) == true { return true }
            if extraField(item)?.lowercased().contains(needle) == true { return true }
            if categoryName(item)?.lowercased().contains(needle) == true { return true }
            if "\(item.amount)".contains(needle) { return true }
            if let base = item.baseCurrencyAmount, "\(base)".contains(needle) { return true }
            return false
        }
    }
}
