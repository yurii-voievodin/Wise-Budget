import Foundation
import SwiftData

@Model
final class Expense {
    var amount: Decimal
    var currency: String
    var date: Date

    init(amount: Decimal, currency: String, date: Date = Date()) {
        self.amount = amount
        self.currency = currency
        self.date = date
    }
}
