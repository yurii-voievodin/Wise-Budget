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

    @Test func promptEncodingIncludesHeaderAndCategories() {
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
        #expect(prompt.contains("Income sources:"))
        #expect(prompt.contains("+2000.00  Salary  ACME Corp"))
        #expect(prompt.contains("Top spending categories:"))
        #expect(prompt.contains("1. Rent  400.00 (73%)"))
        #expect(prompt.contains("2. Groceries  150.00 (27%)"))
        // Per-row expense ledger no longer rendered.
        #expect(!prompt.contains("Expense transactions"))
        #expect(!prompt.contains("-400.00  Rent"))
    }

    @Test func promptEncodingRendersAggregations() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        let cafes = ExpenseCategory(name: "Cafes")
        let medical = ExpenseCategory(name: "Medical")
        let groceries = ExpenseCategory(name: "Groceries")
        let personal = ExpenseCategory(name: "Personal Items")
        [auto, cafes, medical, groceries, personal].forEach { context.insert($0) }

        let expenses: [Expense] = [
            // Recurring fuel
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV"),
            Expense(amount: 74, currency: "EUR", date: date(2026, 3, 20), category: auto, destination: "OMV"),
            // Cross-category merchant
            Expense(amount: 234, currency: "EUR", date: date(2026, 3, 8), category: medical, destination: "Pulse"),
            Expense(amount: 10, currency: "EUR", date: date(2026, 3, 18), category: groceries, destination: "Pulse"),
            // Two MacBook charges — not recurring (need 3+), so each lands as
            // its own one-off line.
            Expense(amount: 1200, currency: "EUR", date: date(2026, 3, 5), category: personal, destination: "MacBook Pro M5 Pro"),
            Expense(amount: 1000, currency: "EUR", date: date(2026, 3, 6), category: personal, destination: "MacBook Pro M5 Pro"),
            // Standalone large one-off
            Expense(amount: 580, currency: "EUR", date: date(2026, 3, 15), category: cafes, destination: "Big Dinner"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        let prompt = summary.encodedAsPrompt()

        #expect(prompt.contains("Recurring merchants (>=3 charges this month):"))
        #expect(prompt.contains("- OMV x 3 = 242.00 (avg 80.67)  (Auto)"))

        #expect(prompt.contains("Largest one-off expenses:"))
        #expect(prompt.contains("- 1200.00  Personal Items  MacBook Pro M5 Pro"))
        #expect(prompt.contains("- 1000.00  Personal Items  MacBook Pro M5 Pro"))
        #expect(prompt.contains("- 580.00  Cafes  Big Dinner"))

        #expect(prompt.contains("Merchants split across categories:"))
        #expect(prompt.contains("- Pulse: Groceries, Medical"))
    }

    @Test func promptEncodingOmitsEmptySections() {
        let summary = SpendingSummary(
            month: "March 2026",
            currency: "EUR",
            totalIncome: 0,
            totalExpenses: 0,
            balance: 0,
            transactionCount: 0,
            topCategories: []
        )

        let prompt = summary.encodedAsPrompt()

        // Only the header is rendered; section headers for empty sections
        // must NOT appear in the prompt.
        #expect(!prompt.contains("Income sources:"))
        #expect(!prompt.contains("Top spending categories:"))
        #expect(!prompt.contains("Recurring merchants"))
        #expect(!prompt.contains("Subscription-like charges"))
        #expect(!prompt.contains("Largest one-off expenses"))
        #expect(!prompt.contains("Merchants split across categories"))
    }

    @Test func promptEncodingSectionOrder() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        let sub = ExpenseCategory(name: "Subscription")
        let med = ExpenseCategory(name: "Medical")
        let groc = ExpenseCategory(name: "Groceries")
        let salary = IncomeCategory(name: "Salary")
        [auto, sub, med, groc].forEach { context.insert($0) }
        context.insert(salary)

        // Need every section to be non-empty.
        let expenses: [Expense] = [
            // Recurring
            Expense(amount: 80, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV"),
            Expense(amount: 74, currency: "EUR", date: date(2026, 3, 20), category: auto, destination: "OMV"),
            // Subscription (category-based)
            Expense(amount: 9, currency: "EUR", date: date(2026, 3, 5), category: sub, destination: "Megogo"),
            // Cross-category
            Expense(amount: 200, currency: "EUR", date: date(2026, 3, 5), category: med, destination: "Pulse"),
            Expense(amount: 10, currency: "EUR", date: date(2026, 3, 8), category: groc, destination: "Pulse"),
            // Large one-off
            Expense(amount: 1200, currency: "EUR", date: date(2026, 3, 5), category: med, destination: "MacBook Pro M5 Pro"),
        ]
        let incomes = [
            Income(amount: 2000, currency: "EUR", date: date(2026, 3, 1), category: salary, source: "ACME"),
        ]
        expenses.forEach { context.insert($0) }
        incomes.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: incomes
        )

        let prompt = summary.encodedAsPrompt()

        let order: [String] = [
            "Income sources:",
            "Top spending categories:",
            "Recurring merchants",
            "Subscription-like charges:",
            "Largest one-off expenses:",
            "Merchants split across categories:",
        ]
        var cursor = prompt.startIndex
        for marker in order {
            guard let range = prompt.range(of: marker, range: cursor..<prompt.endIndex) else {
                Issue.record("Marker \"\(marker)\" not found in prompt or out of order")
                return
            }
            cursor = range.upperBound
        }
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

    // MARK: - Aggregations

    @Test func recurringMerchantBoundary() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        context.insert(auto)

        let expenses = [
            Expense(amount: 80, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV"),
            Expense(amount: 78, currency: "EUR", date: date(2026, 3, 20), category: auto, destination: "OMV"),
            Expense(amount: 60, currency: "EUR", date: date(2026, 3, 22), category: auto, destination: "Shell"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.recurringMerchants.count == 1)
        #expect(summary.recurringMerchants.first?.canonicalKey == "omv")
        #expect(summary.recurringMerchants.first?.count == 3)
        #expect(summary.recurringMerchants.first?.total == 242)
        #expect(summary.recurringMerchants.first?.averagePerCharge ?? 0 > 80 && summary.recurringMerchants.first?.averagePerCharge ?? 0 < 81)
    }

    @Test func recurringRequiresThreeOrMore() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        context.insert(auto)

        let expenses = [
            Expense(amount: 80, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.recurringMerchants.isEmpty)
    }

    @Test func recurringCanonicalisesMerchantVariants() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        context.insert(auto)

        let expenses = [
            Expense(amount: 80, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV TANK 482"),
            Expense(amount: 78, currency: "EUR", date: date(2026, 3, 20), category: auto, destination: "omv-bratislava"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.recurringMerchants.count == 1)
        #expect(summary.recurringMerchants.first?.canonicalKey == "omv")
        #expect(summary.recurringMerchants.first?.count == 3)
    }

    @Test func subscriptionHeuristicLowVarianceLowAmount() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sub = ExpenseCategory(name: "Misc")
        context.insert(sub)

        let expenses = [
            Expense(amount: 18, currency: "EUR", date: date(2026, 3, 5), category: sub, destination: "Mystery Stream"),
            Expense(amount: 18, currency: "EUR", date: date(2026, 3, 20), category: sub, destination: "Mystery Stream"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.subscriptionLikeCharges.count == 1)
        #expect(summary.subscriptionLikeCharges.first?.count == 2)
    }

    @Test func subscriptionHeuristicRejectsHighVariance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let cafes = ExpenseCategory(name: "Cafes")
        context.insert(cafes)

        let expenses = [
            Expense(amount: 4, currency: "EUR", date: date(2026, 3, 5), category: cafes, destination: "Random Coffee"),
            Expense(amount: 25, currency: "EUR", date: date(2026, 3, 6), category: cafes, destination: "Random Coffee"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.subscriptionLikeCharges.isEmpty)
    }

    @Test func subscriptionHeuristicRejectsAboveCap() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let groceries = ExpenseCategory(name: "Groceries")
        context.insert(groceries)

        let expenses = [
            Expense(amount: 35, currency: "EUR", date: date(2026, 3, 5), category: groceries, destination: "Lidl"),
            Expense(amount: 36, currency: "EUR", date: date(2026, 3, 6), category: groceries, destination: "Lidl"),
            Expense(amount: 35, currency: "EUR", date: date(2026, 3, 12), category: groceries, destination: "Lidl"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        // Above the €25 cap → recurring (3+) but not subscription-like.
        #expect(summary.recurringMerchants.count == 1)
        #expect(summary.subscriptionLikeCharges.isEmpty)
    }

    @Test func subscriptionByCategoryWorksAtCountOne() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let subscription = ExpenseCategory(name: "Subscription")
        context.insert(subscription)

        let expenses = [
            Expense(amount: 8, currency: "EUR", date: date(2026, 3, 5), category: subscription, destination: "Megogo"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.subscriptionLikeCharges.count == 1)
        #expect(summary.subscriptionLikeCharges.first?.count == 1)
    }

    @Test func subscriptionExcludesRecurringOverlap() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sub = ExpenseCategory(name: "Subscription")
        context.insert(sub)

        // 5 charges all in Subscription category — qualifies as both
        // recurring (>=3) and subscription (category-based). We dedupe to
        // recurring so the model doesn't see the same merchant twice.
        let expenses = (0..<5).map { i in
            Expense(amount: 18, currency: "EUR", date: date(2026, 3, 5 + i), category: sub, destination: "Claude")
        }
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.recurringMerchants.count == 1)
        #expect(summary.recurringMerchants.first?.canonicalKey == "claude")
        #expect(summary.subscriptionLikeCharges.isEmpty)
    }

    @Test func largestOneOffsExcludeRecurring() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let auto = ExpenseCategory(name: "Auto")
        let other = ExpenseCategory(name: "Other")
        let home = ExpenseCategory(name: "Home")
        [auto, other, home].forEach { context.insert($0) }

        let expenses = [
            Expense(amount: 80, currency: "EUR", date: date(2026, 3, 5), category: auto, destination: "OMV"),
            Expense(amount: 84, currency: "EUR", date: date(2026, 3, 12), category: auto, destination: "OMV"),
            Expense(amount: 78, currency: "EUR", date: date(2026, 3, 20), category: auto, destination: "OMV"),
            Expense(amount: 1008, currency: "EUR", date: date(2026, 3, 8), category: other, destination: "Hertz repair"),
            Expense(amount: 500, currency: "EUR", date: date(2026, 3, 15), category: home, destination: "Furniture"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.largestOneOffs.count == 2)
        #expect(summary.largestOneOffs.first?.label == "Hertz repair")
        #expect(summary.largestOneOffs.first?.amount == 1008)
        #expect(summary.largestOneOffs.allSatisfy { $0.label != "OMV" })
    }

    @Test func largestOneOffsCappedAtFive() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let other = ExpenseCategory(name: "Other")
        context.insert(other)

        let expenses = (1...8).map { i in
            Expense(amount: Decimal(100 * i), currency: "EUR", date: date(2026, 3, i), category: other, destination: "Merchant\(i)")
        }
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.largestOneOffs.count == 5)
        #expect(summary.largestOneOffs.first?.amount == 800)
    }

    @Test func crossCategoryMerchantsSurfaceCategorisationDrift() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let medical = ExpenseCategory(name: "Medical")
        let groceries = ExpenseCategory(name: "Groceries")
        [medical, groceries].forEach { context.insert($0) }

        let expenses = [
            Expense(amount: 234, currency: "EUR", date: date(2026, 3, 5), category: medical, destination: "Pulse"),
            Expense(amount: 10, currency: "EUR", date: date(2026, 3, 12), category: groceries, destination: "Pulse"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.crossCategoryMerchants.count == 1)
        let entry = summary.crossCategoryMerchants.first
        #expect(entry?.canonicalKey == "pulse")
        #expect(entry?.categories == ["Groceries", "Medical"])
    }

    @Test func crossCategoryRequiresAtLeastTwoOccurrences() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let medical = ExpenseCategory(name: "Medical")
        let groceries = ExpenseCategory(name: "Groceries")
        [medical, groceries].forEach { context.insert($0) }

        // Only one charge each — not the same merchant repeating.
        let expenses = [
            Expense(amount: 50, currency: "EUR", date: date(2026, 3, 5), category: medical, destination: "Random Clinic"),
            Expense(amount: 30, currency: "EUR", date: date(2026, 3, 12), category: groceries, destination: "Random Store"),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.crossCategoryMerchants.isEmpty)
    }

    @Test func aggregationIgnoresMissingMerchantStrings() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let other = ExpenseCategory(name: "Other")
        context.insert(other)

        // No destination on any of these — they should not group as one
        // merchant just because they share a nil label.
        let expenses = [
            Expense(amount: 10, currency: "EUR", date: date(2026, 3, 5), category: other, destination: nil),
            Expense(amount: 12, currency: "EUR", date: date(2026, 3, 6), category: other, destination: nil),
            Expense(amount: 14, currency: "EUR", date: date(2026, 3, 7), category: other, destination: nil),
        ]
        expenses.forEach { context.insert($0) }

        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: expenses,
            incomes: []
        )

        #expect(summary.recurringMerchants.isEmpty)
        #expect(summary.subscriptionLikeCharges.isEmpty)
        #expect(summary.crossCategoryMerchants.isEmpty)
    }

    @Test func emptyMonthHasEmptyAggregations() {
        let summary = SpendingSummary.build(
            monthFilter: march2026(),
            currency: "EUR",
            expenses: [],
            incomes: []
        )
        #expect(summary.recurringMerchants.isEmpty)
        #expect(summary.subscriptionLikeCharges.isEmpty)
        #expect(summary.largestOneOffs.isEmpty)
        #expect(summary.crossCategoryMerchants.isEmpty)
    }
}
