import Testing
import Foundation
import SwiftData
@testable import WiseBudget

@MainActor
struct DataSeederTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self, BudgetPlan.self, BudgetPlanItem.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates an isolated UserDefaults suite and cleans it up after the test.
    private func makeUserDefaults() -> (UserDefaults, String) {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (defaults, suiteName)
    }

    // MARK: - prepopulateCategories

    @Test func prepopulateCategoriesCreatesAllExpenseCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        DataSeeder.prepopulateCategories(in: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(categories.count == DefaultExpenseCategory.allCases.count, "Expected \(DefaultExpenseCategory.allCases.count) expense categories")
    }

    @Test func prepopulateCategoriesIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext

        DataSeeder.prepopulateCategories(in: context)
        DataSeeder.prepopulateCategories(in: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(categories.count == DefaultExpenseCategory.allCases.count, "Calling twice should not duplicate categories")
    }

    @Test func prepopulateCategoriesSetsIconNames() throws {
        let container = try makeContainer()
        let context = container.mainContext

        DataSeeder.prepopulateCategories(in: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        for category in categories {
            #expect(category.iconName != nil, "Category '\(category.name)' should have an icon")
        }
    }

    // MARK: - prepopulateIncomeCategories

    @Test func prepopulateIncomeCategoriesCreatesAll() throws {
        let container = try makeContainer()
        let context = container.mainContext

        DataSeeder.prepopulateIncomeCategories(in: context)

        let categories = try context.fetch(FetchDescriptor<IncomeCategory>())
        #expect(categories.count == DefaultIncomeCategory.allCases.count, "Expected \(DefaultIncomeCategory.allCases.count) income categories")
    }

    @Test func prepopulateIncomeCategoriesIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext

        DataSeeder.prepopulateIncomeCategories(in: context)
        DataSeeder.prepopulateIncomeCategories(in: context)

        let categories = try context.fetch(FetchDescriptor<IncomeCategory>())
        #expect(categories.count == DefaultIncomeCategory.allCases.count)
    }

    // MARK: - prepopulateSubscriptionCategory

    @Test func subscriptionCategoryAddedWhenMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Reset the flag so the seeder runs
        UserDefaults.standard.removeObject(forKey: "didAddSubscriptionCategory")
        defer { UserDefaults.standard.removeObject(forKey: "didAddSubscriptionCategory") }

        DataSeeder.prepopulateSubscriptionCategory(in: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let subscription = categories.first { $0.name == "Subscription" }
        #expect(subscription != nil, "Subscription category should be created")
    }

    @Test func subscriptionCategoryNotDuplicatedWhenExists() throws {
        let container = try makeContainer()
        let context = container.mainContext

        // Pre-insert a Subscription category
        context.insert(ExpenseCategory(name: "Subscription", iconName: "repeat"))

        UserDefaults.standard.removeObject(forKey: "didAddSubscriptionCategory")
        defer { UserDefaults.standard.removeObject(forKey: "didAddSubscriptionCategory") }

        DataSeeder.prepopulateSubscriptionCategory(in: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let subscriptionCount = categories.filter { $0.name == "Subscription" }.count
        #expect(subscriptionCount == 1, "Should not duplicate existing Subscription category")
    }
}
