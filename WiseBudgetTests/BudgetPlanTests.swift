import Testing
import Foundation
import SwiftData
@testable import WiseBudget

@MainActor
struct BudgetPlanTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([BudgetPlan.self, BudgetPlanItem.self, Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - startOfMonth

    @Test func startOfMonthMarch2026() throws {
        let container = try makeContainer()
        let plan = BudgetPlan(year: 2026, month: 3)
        container.mainContext.insert(plan)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: plan.startOfMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 1)
    }

    @Test func startOfMonthJanuary() throws {
        let container = try makeContainer()
        let plan = BudgetPlan(year: 2026, month: 1)
        container.mainContext.insert(plan)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: plan.startOfMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 1)
    }

    // MARK: - startOfNextMonth

    @Test func startOfNextMonthMarch2026() throws {
        let container = try makeContainer()
        let plan = BudgetPlan(year: 2026, month: 3)
        container.mainContext.insert(plan)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: plan.startOfNextMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 1)
    }

    @Test func startOfNextMonthDecemberWrapsToJanuary() throws {
        let container = try makeContainer()
        let plan = BudgetPlan(year: 2025, month: 12)
        container.mainContext.insert(plan)

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: plan.startOfNextMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 1)
    }

    // MARK: - displayTitle

    @Test func displayTitleFormat() throws {
        let container = try makeContainer()
        let plan = BudgetPlan(year: 2026, month: 3)
        container.mainContext.insert(plan)

        #expect(plan.displayTitle.contains("March"))
        #expect(plan.displayTitle.contains("2026"))
    }
}
