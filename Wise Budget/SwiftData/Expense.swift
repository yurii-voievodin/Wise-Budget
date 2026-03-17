import Foundation
import SwiftData

@Model
final class Expense {
    var amount: Decimal
    var currency: String
    var date: Date
    var category: ExpenseCategory?

    init(amount: Decimal, currency: String, date: Date = Date(), category: ExpenseCategory? = nil) {
        self.amount = amount
        self.currency = currency
        self.date = date
        self.category = category
    }
}
