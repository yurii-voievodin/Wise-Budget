import Testing
import Foundation
import SwiftData
@testable import WiseBudget

@MainActor
struct SpendingSummaryTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func march2026() -> MonthFilter {
        MonthFilter(year: 2026, month: 3)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func emptySummaryIsFlaggedEmpty() {
        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: [],
            incomes: []
        )
        #expect(summary.isEmpty)
        #expect(summary.transactionCount == 0)
        #expect(summary.totalExpenses == 0)
        #expect(summary.totalIncome == 0)
        #expect(summary.topCategories.isEmpty)
    }

    @Test func totalsSumConvertedAmounts() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        let rent = ExpenseCategory(name: "Rent")
        let salary = IncomeCategory(name: "Salary")
        context.insert(groceries)
        context.insert(rent)
        context.insert(salary)

        let e1 = Expense(amount: 100, currency: "EUR", date: date(2026, 3, 5), category: groceries)
        let e2 = Expense(amount: 400, currency: "EUR", date: date(2026, 3, 10), category: rent)
        let e3 = Expense(amount: 50, currency: "EUR", date: date(2026, 3, 12), category: groceries)
        let i1 = Income(amount: 2000, currency: "EUR", date: date(2026, 3, 1), category: salary)
        [e1, e2, e3].forEach { context.insert($0) }
        context.insert(i1)

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: [e1, e2, e3],
            incomes: [i1]
        )

        #expect(summary.totalExpenses == 550)
        #expect(summary.totalIncome == 2000)
        #expect(summary.balance == 1450)
        #expect(summary.transactionCount == 4)
        #expect(summary.currency == "EUR")
    }

    @Test func topCategoriesSortedByAmountDescending() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        let rent = ExpenseCategory(name: "Rent")
        let fun = ExpenseCategory(name: "Fun")
        [groceries, rent, fun].forEach { context.insert($0) }

        let expenses = [
            Expense(amount: 150, currency: "EUR", date: date(2026, 3, 5), category: groceries),
            Expense(amount: 400, currency: "EUR", date: date(2026, 3, 10), category: rent),
            Expense(amount: 30, currency: "EUR", date: date(2026, 3, 12), category: fun),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.topCategories.count == 3)
        #expect(summary.topCategories[0].name == "Rent")
        #expect(summary.topCategories[0].amount == 400)
        #expect(summary.topCategories[1].name == "Groceries")
        #expect(summary.topCategories[2].name == "Fun")
    }

    @Test func topCategoriesRespectLimit() throws {
        let container = try makeContainer()
        let context = container.mainContext

        var expenses: [Expense] = []
        for i in 1...10 {
            let category = ExpenseCategory(name: "Cat\(i)")
            context.insert(category)
            let exp = Expense(amount: Decimal(i * 10), currency: "EUR", date: date(2026, 3, i), category: category)
            context.insert(exp)
            expenses.append(exp)
        }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: [],
            topCategoryLimit: 3
        )

        #expect(summary.topCategories.count == 3)
        #expect(summary.topCategories[0].name == "Cat10")
        #expect(summary.topCategories[1].name == "Cat9")
        #expect(summary.topCategories[2].name == "Cat8")
    }

    @Test func uncategorizedExpensesGrouped() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let expenses = [
            Expense(amount: 20, currency: "EUR", date: date(2026, 3, 5), category: nil),
            Expense(amount: 30, currency: "EUR", date: date(2026, 3, 6), category: nil),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.topCategories.count == 1)
        #expect(summary.topCategories[0].name == "Uncategorized")
        #expect(summary.topCategories[0].amount == 50)
    }

    @Test func monthLabelFormatted() {
        let summary = SpendingSummary.build(
            monthFilter: MonthFilter(year: 2026, month: 3),
            currency: "EUR",
            expenses: [],
            incomes: []
        )
        #expect(summary.month.contains("2026"))
        #expect(summary.month.lowercased().contains("march") || summary.month.lowercased().contains("mar"))
    }

    @Test func promptEncodingIncludesTotalsAndLedger() {
        let summary = SpendingSummary(
            month: "March 2026",
            currency: "EUR",
            totalIncome: 2000,
            totalExpenses: 550,
            balance: 1450,
            transactionCount: 4,
            topCategories: [
                .init(name: "Rent", amount: 400, percentOfExpenses: 72.7),
                .init(name: "Groceries", amount: 150, percentOfExpenses: 27.3),
            ],
            incomes: [
                .init(amount: 2000, category: "Salary", label: "ACME Corp"),
            ],
            expenses: [
                .init(amount: 400, category: "Rent", label: nil),
                .init(amount: 150, category: "Groceries", label: "Whole Foods"),
            ]
        )

        let prompt = summary.encodedAsPrompt()

        #expect(prompt.contains("Month: March 2026 (EUR)"))
        #expect(prompt.contains("Income: 2000.00"))
        #expect(prompt.contains("Expenses: 550.00"))
        #expect(prompt.contains("Balance: 1450.00"))
        #expect(prompt.contains("Savings: 73%"))
        #expect(prompt.contains("Transactions: 4"))
        #expect(prompt.contains("Income transactions"))
        #expect(prompt.contains("+2000.00  Salary  ACME Corp"))
        #expect(prompt.contains("Expense transactions"))
        #expect(prompt.contains("-400.00  Rent"))
        #expect(prompt.contains("-150.00  Groceries  Whole Foods"))
    }

    @Test func percentagesSumApproximatelyToHundred() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let a = ExpenseCategory(name: "A")
        let b = ExpenseCategory(name: "B")
        context.insert(a)
        context.insert(b)

        let expenses = [
            Expense(amount: 75, currency: "EUR", date: date(2026, 3, 5), category: a),
            Expense(amount: 25, currency: "EUR", date: date(2026, 3, 6), category: b),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        let totalPct = summary.topCategories.reduce(0.0) { $0 + $1.percentOfExpenses }
        #expect(abs(totalPct - 100.0) < 0.01)
    }
}
