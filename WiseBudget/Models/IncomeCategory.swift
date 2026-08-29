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
        return DefaultIncomeCategory.icon(for: name) ?? iconName ?? "folder"
    }

    init(name: String, iconName: String = "folder") {
        self.name = name
        self.iconName = iconName
    }
}
