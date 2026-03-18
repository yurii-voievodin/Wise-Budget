import Foundation
import SwiftData

@Model
final class Expense {
    var amount: Decimal
    var currency: String
    var date: Date
    var category: ExpenseCategory?
    var descriptionText: String?
    var destination: String?

    init(amount: Decimal, currency: String, date: Date = Date(), category: ExpenseCategory? = nil, descriptionText: String? = nil, destination: String? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
        self.descriptionText = descriptionText
        self.destination = destination
    }
}
