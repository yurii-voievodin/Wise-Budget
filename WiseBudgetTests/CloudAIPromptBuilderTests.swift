import Testing
import Foundation
import SwiftData
@testable import WiseBudget

struct CloudAIPromptBuilderTests {

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

    private func summary(
        for expenses: [Expense],
        incomes: [Income] = [],
        monthFilter: MonthFilter = MonthFilter(year: 2026, month: 4),
        currency: String = "USD"
    ) -> SpendingSummary {
        SpendingSummary.build(
            monthFilter: monthFilter,
            currency: currency,
            expenses: expenses,
            incomes: incomes,
            topCategoryLimit: .max
        )
    }

    // MARK: - Intro / framing

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

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [expense]),
            baseCurrency: "USD"
        )

        #expect(payload.contains("Base currency: USD."))
        #expect(payload.contains("## Monthly summary — April 2026"))
    }

    @Test func buildOmitsRawTransactionAppendix() throws {
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

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [expense]),
            baseCurrency: "USD"
        )

        #expect(!payload.contains("## Transactions"))
        #expect(!payload.contains("Amount (origin)"))
    }

    @Test func buildAddsResponseLanguageDirectiveWhenProvided() throws {
        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: []),
            baseCurrency: "USD",
            responseLanguageName: "Ukrainian"
        )

        #expect(payload.contains("Please respond in Ukrainian."))
    }

    @Test func buildOmitsResponseLanguageDirectiveWhenNil() throws {
        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: []),
            baseCurrency: "USD",
            responseLanguageName: nil
        )

        #expect(!payload.contains("Please respond in"))
    }

    @Test func buildOmitsResponseLanguageDirectiveWhenEmpty() throws {
        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: []),
            baseCurrency: "USD",
            responseLanguageName: ""
        )

        #expect(!payload.contains("Please respond in"))
    }

    // MARK: - Totals & savings

    @Test func buildIncludesTotalsAndSavingsPercentage() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)
        let salary = IncomeCategory(name: "Salary")
        context.insert(salary)

        let expense = Expense(
            amount: 200,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 2),
            category: groceries,
            descriptionText: "ATB"
        )
        let income = Income(
            amount: 1_000,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 1),
            category: salary,
            descriptionText: "April salary",
            source: "Acme"
        )
        context.insert(expense)
        context.insert(income)

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [expense], incomes: [income]),
            baseCurrency: "USD"
        )

        #expect(payload.contains("- Income: 1,000.00 USD"))
        #expect(payload.contains("- Expenses: 200.00 USD"))
        #expect(payload.contains("- Balance: 800.00 USD"))
        #expect(payload.contains("- Savings: 80%"))
        #expect(payload.contains("- Transactions: 2"))
    }

    // MARK: - Spending by category — per-category subsections

    @Test func buildIncludesAllCategoriesNotJustTop() throws {
        let container = try makeContainer()
        let context = container.mainContext

        var expenses: [Expense] = []
        for i in 1...10 {
            let category = ExpenseCategory(name: "Cat\(i)")
            context.insert(category)
            let expense = Expense(
                amount: Decimal(i * 10),
                currency: "USD",
                date: try makeDate(year: 2026, month: 4, day: i),
                category: category,
                descriptionText: "Charge \(i)"
            )
            context.insert(expense)
            expenses.append(expense)
        }

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: expenses),
            baseCurrency: "USD"
        )

        #expect(payload.contains("### Spending by category"))
        for i in 1...10 {
            #expect(payload.contains("#### Cat\(i) —"), "Expected #### Cat\(i) heading in payload, missing.")
        }
    }

    @Test func buildListsEveryTransactionUnderItsCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        let electronics = ExpenseCategory(name: "Electronics")
        context.insert(groceries)
        context.insert(electronics)

        // 3 charges at the same merchant in Groceries — must appear as 3
        // separate lines, not collapsed.
        let charges = (1...3).map { day in
            Expense(
                amount: 30,
                currency: "USD",
                date: (try? makeDate(year: 2026, month: 4, day: day)) ?? Date.now,
                category: groceries,
                descriptionText: "Lidl",
                destination: "Lidl"
            )
        }
        let mac = Expense(
            amount: 1500,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 4),
            category: electronics,
            descriptionText: "MacBook",
            destination: "Apple Store"
        )
        for expense in charges + [mac] { context.insert(expense) }

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: charges + [mac]),
            baseCurrency: "USD"
        )

        // Lidl line appears 3 times under Groceries.
        let lidlOccurrences = payload.components(separatedBy: "30.00 USD — Lidl").count - 1
        #expect(lidlOccurrences == 3)
        // Apple Store appears once under Electronics.
        #expect(payload.contains("1,500.00 USD — Apple Store"))
    }

    @Test func buildSortsTransactionsWithinCategoryByAmountDescending() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)

        let small = Expense(
            amount: 10,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 5),
            category: groceries,
            descriptionText: "Small Bag",
            destination: "Corner Shop"
        )
        let large = Expense(
            amount: 200,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 20),
            category: groceries,
            descriptionText: "Big Haul",
            destination: "Big Market"
        )
        context.insert(small)
        context.insert(large)

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [small, large]),
            baseCurrency: "USD"
        )

        let categoryRange = try #require(payload.range(of: "#### Groceries —")).upperBound
        let categoryText = String(payload[categoryRange...])
        let largeIdx = try #require(categoryText.range(of: "Big Market"))
        let smallIdx = try #require(categoryText.range(of: "Corner Shop"))
        #expect(largeIdx.lowerBound < smallIdx.lowerBound)
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

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [expense]),
            baseCurrency: "USD"
        )

        #expect(payload.contains("#### Uncategorized —"))
    }

    // MARK: - Income sources

    @Test func buildSurfacesIncomeSourceWhenPresent() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let salary = IncomeCategory(name: "Salary")
        context.insert(salary)
        let income = Income(
            amount: 5_000,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 1),
            category: salary,
            descriptionText: "April salary",
            source: "Acme Corp"
        )
        context.insert(income)

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: [], incomes: [income]),
            baseCurrency: "USD"
        )

        #expect(payload.contains("### Income sources"))
        #expect(payload.contains("5,000.00 USD — Salary"))
        #expect(payload.contains("Acme Corp"))
    }

    // MARK: - Section trimming

    @Test func buildOmitsRecurringCrossCategoryAndMerchantsSections() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let groceries = ExpenseCategory(name: "Groceries")
        let medical = ExpenseCategory(name: "Medical")
        context.insert(groceries)
        context.insert(medical)

        let recurring = (1...3).map { day in
            Expense(
                amount: 30,
                currency: "USD",
                date: (try? makeDate(year: 2026, month: 4, day: day)) ?? Date.now,
                category: groceries,
                descriptionText: "Lidl",
                destination: "Lidl"
            )
        }
        let split = Expense(
            amount: 30,
            currency: "USD",
            date: try makeDate(year: 2026, month: 4, day: 4),
            category: medical,
            descriptionText: "Lidl",
            destination: "Lidl"
        )
        for expense in recurring + [split] { context.insert(expense) }

        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: recurring + [split]),
            baseCurrency: "USD"
        )

        #expect(!payload.contains("### Recurring merchants"))
        #expect(!payload.contains("### Merchants split across categories"))
        #expect(!payload.contains("### Merchants"))
    }

    @Test func buildOmitsEmptySummarySections() throws {
        let payload = CloudAIPromptBuilder.build(
            monthFilter: MonthFilter(year: 2026, month: 4),
            summary: summary(for: []),
            baseCurrency: "USD"
        )

        #expect(payload.contains("## Monthly summary"))
        // Conditional sub-sections must not appear when their data is empty.
        #expect(!payload.contains("### Spending by category"))
        #expect(!payload.contains("### Income sources"))
        #expect(!payload.contains("### Subscription-like charges"))
        #expect(!payload.contains("### Largest one-offs"))
    }
}
