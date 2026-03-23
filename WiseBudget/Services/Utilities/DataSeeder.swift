import Foundation
import SwiftData

enum DataSeeder {

    static func prepopulateCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for category in DefaultExpenseCategory.allCases {
            context.insert(ExpenseCategory(name: category.rawValue, iconName: category.iconName))
        }
    }

    static func prepopulateIncomeCategories(in context: ModelContext) {
        let descriptor = FetchDescriptor<IncomeCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for category in DefaultIncomeCategory.allCases {
            context.insert(IncomeCategory(name: category.rawValue, iconName: category.iconName))
        }
    }

    static func migrateCategoryIcons(in context: ModelContext) {
        let key = "didMigrateCategoryIcons"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let expenseIcons = Dictionary(
            uniqueKeysWithValues: DefaultExpenseCategory.allCases.map { ($0.rawValue, $0.iconName) }
        )
        let incomeIcons = Dictionary(
            uniqueKeysWithValues: DefaultIncomeCategory.allCases.map { ($0.rawValue, $0.iconName) }
        )

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

    static func prepopulateSubscriptionCategory(in context: ModelContext) {
        let key = "didAddSubscriptionCategory"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let descriptor = FetchDescriptor<ExpenseCategory>()
        guard let existing = try? context.fetch(descriptor) else { return }

        let name = DefaultExpenseCategory.subscription.rawValue
        guard !existing.contains(where: { $0.name == name }) else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        context.insert(ExpenseCategory(
            name: name,
            iconName: DefaultExpenseCategory.subscription.iconName
        ))
        UserDefaults.standard.set(true, forKey: key)
    }
}
