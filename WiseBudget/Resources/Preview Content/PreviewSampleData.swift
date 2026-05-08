import Foundation
import SwiftData

struct PreviewSampleData {
    static var container: ModelContainer {
        let container = try! ModelContainer(
            for: Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self,
            BudgetPlan.self, BudgetPlanItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        // Expense categories
        let groceries = ExpenseCategory(name: "Groceries")
        let transport = ExpenseCategory(name: "Transport")
        let entertainment = ExpenseCategory(name: "Entertainment")
        let utilities = ExpenseCategory(name: "Utilities")
        for cat in [groceries, transport, entertainment, utilities] {
            context.insert(cat)
        }

        // Income categories
        let salary = IncomeCategory(name: "Salary")
        let freelance = IncomeCategory(name: "Freelance")
        let dividends = IncomeCategory(name: "Dividends", iconName: "chart.line.uptrend.xyaxis")
        for cat in [salary, freelance, dividends] {
            context.insert(cat)
        }

        let calendar = Calendar.current
        func date(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        // Expenses
        let expenses: [Expense] = [
            Expense(amount: 52.30, currency: "USD", date: date(year: 2026, month: 3, day: 17), category: groceries, descriptionText: "Weekly grocery run"),
            Expense(amount: 15.00, currency: "USD", date: date(year: 2026, month: 3, day: 16), category: transport, descriptionText: "Uber to office"),
            Expense(amount: 120.00, currency: "EUR", date: date(year: 2026, month: 3, day: 15), category: entertainment),
            Expense(amount: 85.50, currency: "USD", date: date(year: 2026, month: 3, day: 14), category: utilities),
            Expense(amount: 34.99, currency: "USD", date: date(year: 2026, month: 3, day: 12), category: groceries),
            Expense(amount: 9.75, currency: "EUR", date: date(year: 2026, month: 3, day: 10), category: transport),
            Expense(amount: 250.00, currency: "USD", date: date(year: 2026, month: 2, day: 28), category: entertainment),
            Expense(amount: 42.00, currency: "USD", date: date(year: 2026, month: 2, day: 20), category: groceries),
        ]
        for expense in expenses { context.insert(expense) }

        // Incomes
        let incomes: [Income] = [
            Income(amount: 4500.00, currency: "USD", date: date(year: 2026, month: 3, day: 1), category: salary, descriptionText: "March salary"),
            Income(amount: 800.00, currency: "EUR", date: date(year: 2026, month: 3, day: 10), category: freelance, descriptionText: "Logo design project"),
            Income(amount: 150.00, currency: "USD", date: date(year: 2026, month: 3, day: 15), category: dividends),
            Income(amount: 4500.00, currency: "USD", date: date(year: 2026, month: 2, day: 1), category: salary),
            Income(amount: 1200.00, currency: "USD", date: date(year: 2026, month: 2, day: 14), category: freelance),
        ]
        for income in incomes { context.insert(income) }

        // Budget plan for March 2026
        let marchPlan = BudgetPlan(year: 2026, month: 3)
        context.insert(marchPlan)
        let planItems: [(ExpenseCategory, Decimal)] = [
            (groceries, 200),
            (transport, 100),
            (entertainment, 150),
            (utilities, 120),
        ]
        for (cat, amount) in planItems {
            let item = BudgetPlanItem(plannedAmount: amount, plan: marchPlan, category: cat)
            context.insert(item)
        }

        return container
    }

    /// Container seeded for the current month where the user is spending
    /// at an unsustainable pace but still has room to course-correct.
    /// Designed to trigger `DashboardView`'s Budget Pacing section.
    static var overspendingPaceContainer: ModelContainer {
        let container = try! ModelContainer(
            for: Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self,
            BudgetPlan.self, BudgetPlanItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        let transport = ExpenseCategory(name: "Transport")
        let entertainment = ExpenseCategory(name: "Entertainment")
        let salary = IncomeCategory(name: "Salary")
        for cat in [groceries, transport, entertainment] { context.insert(cat) }
        context.insert(salary)

        let calendar = Calendar.current
        let now = Date.now
        let month = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(
            from: DateComponents(year: month.year, month: month.month, day: 1)
        )!
        let daysElapsed = calendar.component(.day, from: now)
        let currency = DefaultCurrency.resolve()

        context.insert(Income(
            amount: 3000, currency: currency, date: startOfMonth,
            category: salary, descriptionText: "Monthly salary"
        ))

        let perDay: Decimal = 125
        let cats = [groceries, transport, entertainment]
        for day in 1...max(daysElapsed, 1) {
            let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)!
            context.insert(Expense(
                amount: perDay, currency: currency, date: date,
                category: cats[day % cats.count]
            ))
        }

        return container
    }
}
