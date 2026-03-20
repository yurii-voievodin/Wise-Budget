import Foundation
import SwiftData

@Model
final class ExpenseCategory {
    var name: String
    var iconName: String?

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    var displayIconName: String {
        iconName ?? "folder"
    }

    init(name: String, iconName: String = "folder") {
        self.name = name
        self.iconName = iconName
    }
}
