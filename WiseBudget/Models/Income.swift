import Foundation
import SwiftData

@Model
final class Income: CurrencyConvertible {
    var amount: Decimal
    var currency: String
    var date: Date
    var category: IncomeCategory?
    var descriptionText: String?
    var source: String?
    var baseCurrencyAmount: Decimal?
    var baseCurrency: String?
    var externalId: String?

    init(amount: Decimal, currency: String, date: Date = Date.now, category: IncomeCategory? = nil, descriptionText: String? = nil, source: String? = nil, baseCurrencyAmount: Decimal? = nil, baseCurrency: String? = nil, externalId: String? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.descriptionText = descriptionText
        self.source = source
        self.baseCurrencyAmount = baseCurrencyAmount
        self.baseCurrency = baseCurrency
        self.externalId = externalId
    }
}
