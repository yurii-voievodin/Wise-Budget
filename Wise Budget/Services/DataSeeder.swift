import Foundation
import SwiftData

enum DataSeeder {

    static func prepopulateCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaults: [(name: String, icon: String)] = [
            ("Auto", "car"),
            ("Cafes", "cup.and.saucer"),
            ("Entertainment", "film"),
            ("Groceries", "cart"),
            ("Home", "house"),
            ("Medical", "cross.case"),
            ("Other", "ellipsis.circle"),
            ("Personal Items", "bag"),
            ("Taxes", "doc.text"),
            ("Travel", "airplane"),
            ("Utilities", "bolt"),
        ]
        for item in defaults {
            context.insert(ExpenseCategory(name: item.name, iconName: item.icon))
        }
    }

    static func prepopulateIncomeCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<IncomeCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaults: [(name: String, icon: String)] = [
            ("Freelance", "laptopcomputer"),
            ("Gifts", "gift"),
            ("Investments", "chart.line.uptrend.xyaxis"),
            ("Other", "ellipsis.circle"),
            ("Rental", "key"),
            ("Salary", "banknote"),
        ]
        for item in defaults {
            context.insert(IncomeCategory(name: item.name, iconName: item.icon))
        }
    }

    static func migrateCategoryIcons(in context: ModelContext) {
        let key = "didMigrateCategoryIcons"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let expenseIcons: [String: String] = [
            "Auto": "car",
            "Cafes": "cup.and.saucer",
            "Entertainment": "film",
            "Groceries": "cart",
            "Home": "house",
            "Medical": "cross.case",
            "Other": "ellipsis.circle",
            "Personal Items": "bag",
            "Taxes": "doc.text",
            "Travel": "airplane",
            "Utilities": "bolt",
        ]

        let incomeIcons: [String: String] = [
            "Freelance": "laptopcomputer",
            "Gifts": "gift",
            "Investments": "chart.line.uptrend.xyaxis",
            "Other": "ellipsis.circle",
            "Rental": "key",
            "Salary": "banknote",
        ]

        if let expenseCategories = try? context.fetch(FetchDescriptor<ExpenseCategory>()) {
            for category in expenseCategories where category.iconName == nil {
                category.iconName = expenseIcons[category.name]
            }
        }

        if let incomeCategories = try? context.fetch(FetchDescriptor<IncomeCategory>()) {
            for category in incomeCategories where category.iconName == nil {
                category.iconName = incomeIcons[category.name]
            }
        }

        UserDefaults.standard.set(true, forKey: key)
    }
}
