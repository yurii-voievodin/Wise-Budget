import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String) {
        self.name = name
    }
}
