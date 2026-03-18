import Foundation
import SwiftData

@Model
final class Expense: CurrencyConvertible {
    var amount: Decimal
    var currency: String
    var date: Date
    var category: ExpenseCategory?
    var descriptionText: String?
    var destination: String?
    var baseCurrencyAmount: Decimal?
    var baseCurrency: String?

    init(amount: Decimal, currency: String, date: Date = Date(), category: ExpenseCategory? = nil, descriptionText: String? = nil, destination: String? = nil, baseCurrencyAmount: Decimal? = nil, baseCurrency: String? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.descriptionText = descriptionText
        self.destination = destination
        self.baseCurrencyAmount = baseCurrencyAmount
        self.baseCurrency = baseCurrency
    }
}
