import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "DataSeeder")

enum DataSeeder {

    static func prepopulateCategories(in context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<ExpenseCategory>()
            let existingCount = try context.fetchCount(descriptor)
            guard existingCount == 0 else { return }

            for category in DefaultExpenseCategory.allCases {
                context.insert(ExpenseCategory(name: category.rawValue, iconName: category.iconName))
            }
            try context.save()
            logger.info("Prepopulated \(DefaultExpenseCategory.allCases.count) expense categories")
        } catch {
            logger.warning("Failed to prepopulate expense categories: \(error.localizedDescription)")
        }
    }

    static func prepopulateIncomeCategories(in context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<IncomeCategory>()
            let existingCount = try context.fetchCount(descriptor)
            guard existingCount == 0 else { return }

            for category in DefaultIncomeCategory.allCases {
                context.insert(IncomeCategory(name: category.rawValue, iconName: category.iconName))
            }
            try context.save()
            logger.info("Prepopulated \(DefaultIncomeCategory.allCases.count) income categories")
        } catch {
            logger.warning("Failed to prepopulate income categories: \(error.localizedDescription)")
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

        do {
            let expenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
            for category in expenseCategories where category.iconName == nil {
                category.iconName = expenseIcons[category.name]
            }
        } catch {
            logger.warning("Failed to migrate expense category icons: \(error.localizedDescription)")
        }

        do {
            let incomeCategories = try context.fetch(FetchDescriptor<IncomeCategory>())
            for category in incomeCategories where category.iconName == nil {
                category.iconName = incomeIcons[category.name]
            }
        } catch {
            logger.warning("Failed to migrate income category icons: \(error.localizedDescription)")
        }

        do {
            try context.save()
        } catch {
            logger.warning("Failed to save icon migration: \(error.localizedDescription)")
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    static func prepopulateSubscriptionCategory(in context: ModelContext) {
        let key = "didAddSubscriptionCategory"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        do {
            let descriptor = FetchDescriptor<ExpenseCategory>()
            let existing = try context.fetch(descriptor)

            let name = DefaultExpenseCategory.subscription.rawValue
            guard !existing.contains(where: { $0.name == name }) else {
                UserDefaults.standard.set(true, forKey: key)
                return
            }

            context.insert(ExpenseCategory(
                name: name,
                iconName: DefaultExpenseCategory.subscription.iconName
            ))
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            logger.info("Added Subscription category")
        } catch {
            logger.warning("Failed to prepopulate subscription category: \(error.localizedDescription)")
        }
    }
}
