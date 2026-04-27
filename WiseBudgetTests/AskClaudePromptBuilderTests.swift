import Testing
import Foundation
import SwiftData
@testable import WiseBudget

@MainActor
struct AskClaudePromptBuilderTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = Calendar(identifier: .gregorian)
        return try #require(calendar.date(from: components))
    }

    @Test func buildIncludesIntroAndMonthHeading() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)
        let expense = Expense(
            amount: 42.10,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 2),
            category: groceries,
            descriptionText: "ATB"
        )
        context.insert(expense)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [expense],
            baseCurrency: "USD"
        )

        #expect(payload.contains("Base currency: USD."))
        #expect(payload.contains("## Transactions — April 2026"))
        #expect(!payload.contains("Prior month"))
    }

    @Test func buildRendersTransactionRow() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)
        let expense = Expense(
            amount: Decimal(string: "42.10")!,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 2),
            category: groceries,
            descriptionText: "ATB"
        )
        context.insert(expense)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [expense],
            baseCurrency: "USD"
        )

        #expect(payload.contains("| 2026-04-02 | Groceries | 42.10 USD | — | ATB |"))
    }

    @Test func buildShowsOriginalAmountWhenForeignCurrency() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)
        let expense = Expense(
            amount: Decimal(string: "1580")!,
            currency: "UAH",
            date: try makeDate(year: 2026, month: 4, day: 2),
            category: groceries,
            descriptionText: "ATB",
            baseCurrencyAmount: Decimal(string: "42.10")!,
            baseCurrency: "USD"
        )
        context.insert(expense)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [expense],
            baseCurrency: "USD"
        )

        #expect(payload.contains("42.10 USD"))
        #expect(payload.contains("1,580.00 UAH"))
    }

    @Test func buildSortsTransactionsByDate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)

        let later = Expense(
            amount: 20,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 20),
            category: groceries,
            descriptionText: "Later"
        )
        let earlier = Expense(
            amount: 10,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 5),
            category: groceries,
            descriptionText: "Earlier"
        )
        context.insert(later)
        context.insert(earlier)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [later, earlier],
            baseCurrency: "USD"
        )

        let earlierRange = try #require(payload.range(of: "Earlier"))
        let laterRange = try #require(payload.range(of: "Later"))
        #expect(earlierRange.lowerBound < laterRange.lowerBound)
    }

    @Test func buildHandlesEmptyCurrentMonth() throws {
        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [],
            baseCurrency: "USD"
        )

        #expect(payload.contains("_no transactions this month_"))
    }

    @Test func buildHandlesUncategorizedExpense() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let expense = Expense(
            amount: 10,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 1),
            category: nil,
            descriptionText: "Cash"
        )
        context.insert(expense)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [expense],
            baseCurrency: "USD"
        )

        #expect(payload.contains("Uncategorized"))
    }

    @Test func buildEscapesPipeInDescription() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Other")
        context.insert(category)
        let expense = Expense(
            amount: 5,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 1),
            category: category,
            descriptionText: "Pipe | in name"
        )
        context.insert(expense)

        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [expense],
            baseCurrency: "USD"
        )

        #expect(payload.contains("Pipe \\| in name"))
    }

    @Test func buildAddsResponseLanguageDirectiveWhenProvided() throws {
        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [],
            baseCurrency: "USD",
            responseLanguageName: "Ukrainian"
        )

        #expect(payload.contains("Please respond in Ukrainian."))
    }

    @Test func buildOmitsResponseLanguageDirectiveWhenNil() throws {
        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [],
            baseCurrency: "USD",
            responseLanguageName: nil
        )

        #expect(!payload.contains("Please respond in"))
    }

    @Test func buildOmitsResponseLanguageDirectiveWhenEmpty() throws {
        let payload = AskClaudePromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            currentMonthExpenses: [],
            baseCurrency: "USD",
            responseLanguageName: ""
        )

        #expect(!payload.contains("Please respond in"))
    }
}
