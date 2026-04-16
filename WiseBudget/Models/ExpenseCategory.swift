import Foundation
import SwiftData

@Model
final nonisolated class ExpenseCategory {
    var name: String
    var iconName: String?

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    var displayIconName: String {
        if let iconName, iconName != "folder" {
            return iconName
        }
        return DefaultExpenseCategory(rawValue: name)?.iconName ?? iconName ?? "folder"
    }

    init(name: String, iconName: String = "folder") {
        self.name = name
        self.iconName = iconName
    }
}
