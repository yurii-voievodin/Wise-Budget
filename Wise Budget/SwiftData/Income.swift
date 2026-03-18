import Foundation
import SwiftData

@Model
final class Income {
    var amount: Decimal
    var currency: String
    var date: Date
    var category: IncomeCategory?
    var descriptionText: String?

    init(amount: Decimal, currency: String, date: Date = Date(), category: IncomeCategory? = nil, descriptionText: String? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.descriptionText = descriptionText
    }
}
