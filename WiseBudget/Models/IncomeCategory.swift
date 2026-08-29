import Foundation
import SwiftData

@Model
final nonisolated class IncomeCategory {
    var name: String
    var iconName: String?

    @Relationship(deleteRule: .nullify, inverse: \Income.category)
    var incomes: [Income] = []

    var displayIconName: String {
        if let iconName, iconName != "folder" {
            return iconName
        }
        if let match = DefaultIncomeCategory(rawValue: name) {
            return match.iconName
        }
        if let match = DefaultExpenseCategory(rawValue: name) {
            return match.iconName
        }
        return iconName ?? "folder"
    }

    init(name: String, iconName: String = "folder") {
        self.name = name
        self.iconName = iconName
    }
}
