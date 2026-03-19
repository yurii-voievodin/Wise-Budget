import Testing
import Foundation
import SwiftData
@testable import Wise_Budget

@MainActor
struct CSVExportImportTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)!
    }

    // MARK: - CSVExporter Tests

    @Test func exportEmptyDataProducesHeaderOnly() {
        let csv = CSVExporter.exportCSV(expenses: [], incomes: [])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 1)
        #expect(lines[0] == CSVExporter.header)
    }

    @Test func exportSingleExpense() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Groceries")
        context.insert(category)

        let expense = Expense(
            amount: 15.98,
            currency: "EUR",
            date: makeDate(year: 2026, month: 3, day: 15),
            category: category,
            descriptionText: "Kaufland",
            destination: nil
        )
        context.insert(expense)

        let csv = CSVExporter.exportCSV(expenses: [expense], incomes: [])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2)

        let fields = CSVImporter.parseCSVLine(lines[1])
        #expect(fields[0] == "Expense")
        #expect(fields[2] == "15.98")
        #expect(fields[3] == "EUR")
        #expect(fields[4] == "Groceries")
        #expect(fields[5] == "Kaufland")
    }

    @Test func exportSingleIncome() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = IncomeCategory(name: "Salary")
        context.insert(category)

        let income = Income(
            amount: Decimal(string: "3754.76")!,
            currency: "EUR",
            date: makeDate(year: 2026, month: 2, day: 27),
            category: category,
            descriptionText: "March salary"
        )
        context.insert(income)

        let csv = CSVExporter.exportCSV(expenses: [], incomes: [income])
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2)

        let fields = CSVImporter.parseCSVLine(lines[1])
        #expect(fields[0] == "Income")
        #expect(fields[2] == "3754.76")
        #expect(fields[3] == "EUR")
        #expect(fields[4] == "Salary")
        #expect(fields[5] == "March salary")
    }

    @Test func exportPreservesBaseCurrencyFields() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Other")
        context.insert(category)

        let expense = Expense(
            amount: Decimal(string: "19.08")!,
            currency: "EUR",
            date: makeDate(year: 2026, month: 2, day: 26),
            category: category,
            baseCurrencyAmount: Decimal(string: "80.59")!,
            baseCurrency: "PLN"
        )
        context.insert(expense)

        let csv = CSVExporter.exportCSV(expenses: [expense], incomes: [])
        let lines = csv.components(separatedBy: "\n")
        let fields = CSVImporter.parseCSVLine(lines[1])
        #expect(fields[7] == "80.59")
        #expect(fields[8] == "PLN")
    }

    @Test func exportSortsExpensesByDate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Test")
        context.insert(category)

        let older = Expense(amount: 10, currency: "USD", date: makeDate(year: 2026, month: 1, day: 1), category: category)
        let newer = Expense(amount: 20, currency: "USD", date: makeDate(year: 2026, month: 3, day: 1), category: category)
        context.insert(older)
        context.insert(newer)

        let csv = CSVExporter.exportCSV(expenses: [newer, older], incomes: [])
        let lines = csv.components(separatedBy: "\n")
        let firstFields = CSVImporter.parseCSVLine(lines[1])
        let secondFields = CSVImporter.parseCSVLine(lines[2])
        #expect(firstFields[2] == "10")
        #expect(secondFields[2] == "20")
    }

    @Test func exportEscapesCommasInDescription() {
        let escaped = CSVExporter.escapeField("Deel, Inc.")
        #expect(escaped == "\"Deel, Inc.\"")
    }

    @Test func exportEscapesQuotesInDescription() {
        let escaped = CSVExporter.escapeField("She said \"hello\"")
        #expect(escaped == "\"She said \"\"hello\"\"\"")
    }

    @Test func exportFromContext() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let expCat = ExpenseCategory(name: "Food")
        let incCat = IncomeCategory(name: "Salary")
        context.insert(expCat)
        context.insert(incCat)

        context.insert(Expense(amount: 10, currency: "USD", date: makeDate(year: 2026, month: 3, day: 1), category: expCat))
        context.insert(Income(amount: 5000, currency: "USD", date: makeDate(year: 2026, month: 3, day: 1), category: incCat))

        let csv = try CSVExporter.exportCSV(from: context)
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 3) // header + 1 expense + 1 income
    }

    // MARK: - AppDataCSVImporter Tests

    @Test func importEmptyContent() {
        let rows = AppDataCSVImporter.parseCSV(from: "")
        #expect(rows.isEmpty)
    }

    @Test func importHeaderOnly() {
        let rows = AppDataCSVImporter.parseCSV(from: CSVExporter.header)
        #expect(rows.isEmpty)
    }

    @Test func importSingleExpenseRow() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-03-15,15.98,EUR,Groceries,Kaufland,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.count == 1)
        #expect(rows[0].type == "Expense")
        #expect(rows[0].amount == Decimal(string: "15.98"))
        #expect(rows[0].currency == "EUR")
        #expect(rows[0].category == "Groceries")
        #expect(rows[0].description == "Kaufland")
        #expect(rows[0].destination == nil)
        #expect(rows[0].baseCurrencyAmount == nil)
        #expect(rows[0].baseCurrency == nil)
    }

    @Test func importSingleIncomeRow() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Income,2026-02-27,3754.76,EUR,Salary,March salary,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.count == 1)
        #expect(rows[0].type == "Income")
        #expect(rows[0].amount == Decimal(string: "3754.76"))
        #expect(rows[0].category == "Salary")
        #expect(rows[0].description == "March salary")
    }

    @Test func importRowWithBaseCurrency() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-02-26,19.08,EUR,Other,,,80.59,PLN
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.count == 1)
        #expect(rows[0].baseCurrencyAmount == Decimal(string: "80.59"))
        #expect(rows[0].baseCurrency == "PLN")
    }

    @Test func importSkipsInvalidType() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Unknown,2026-03-15,15.98,EUR,Groceries,Kaufland,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.isEmpty)
    }

    @Test func importSkipsMalformedRows() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        too,few,fields
        Expense,2026-03-15,15.98,EUR,Groceries,Kaufland,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.count == 1)
    }

    @Test func importSkipsInvalidDate() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,not-a-date,15.98,EUR,Groceries,Kaufland,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.isEmpty)
    }

    @Test func importSkipsInvalidAmount() {
        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-03-15,abc,EUR,Groceries,Kaufland,,,
        """
        let rows = AppDataCSVImporter.parseCSV(from: csv)
        #expect(rows.isEmpty)
    }

    @Test func importIntoContextCreatesExpensesAndIncomes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-03-15,15.98,EUR,Groceries,Kaufland,,,
        Expense,2026-03-14,12.84,EUR,Cafes,Glovo,,,
        Income,2026-02-27,3754.76,EUR,Salary,March salary,,,
        """

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        let result = try AppDataCSVImporter.importRows(rows, into: context)

        #expect(result.expensesImported == 2)
        #expect(result.incomesImported == 1)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let incomes = try context.fetch(FetchDescriptor<Income>())
        #expect(expenses.count == 2)
        #expect(incomes.count == 1)
    }

    @Test func importCreatesCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-03-15,10,USD,NewExpCat,,,,
        Income,2026-03-15,100,USD,NewIncCat,,,,
        """

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        let result = try AppDataCSVImporter.importRows(rows, into: context)

        #expect(result.expensesImported == 1)
        #expect(result.incomesImported == 1)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let incomes = try context.fetch(FetchDescriptor<Income>())
        #expect(expenses.first?.category?.name == "NewExpCat")
        #expect(incomes.first?.category?.name == "NewIncCat")
    }

    @Test func importReusesExistingCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ExpenseCategory(name: "Groceries")
        context.insert(existing)

        let csv = """
        Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency
        Expense,2026-03-15,10,USD,Groceries,,,
        Expense,2026-03-16,20,USD,Groceries,,,
        """

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        _ = try AppDataCSVImporter.importRows(rows, into: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let groceriesCount = categories.filter { $0.name == "Groceries" }.count
        #expect(groceriesCount == 1)
    }

    // MARK: - Round-Trip Tests

    @Test func roundTripPreservesExpenseData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Groceries")
        context.insert(category)

        let original = Expense(
            amount: 15.98,
            currency: "EUR",
            date: makeDate(year: 2026, month: 3, day: 15),
            category: category,
            descriptionText: "Kaufland",
            destination: "Berlin"
        )
        context.insert(original)

        // Export
        let csv = CSVExporter.exportCSV(expenses: [original], incomes: [])

        // Import into a fresh context
        let container2 = try makeContainer()
        let context2 = container2.mainContext

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        let result = try AppDataCSVImporter.importRows(rows, into: context2)

        #expect(result.expensesImported == 1)

        let imported = try context2.fetch(FetchDescriptor<Expense>())
        #expect(imported.count == 1)
        #expect(imported[0].amount == original.amount)
        #expect(imported[0].currency == original.currency)
        #expect(imported[0].descriptionText == original.descriptionText)
        #expect(imported[0].destination == original.destination)
        #expect(imported[0].category?.name == "Groceries")
    }

    @Test func roundTripPreservesIncomeData() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = IncomeCategory(name: "Salary")
        context.insert(category)

        let original = Income(
            amount: Decimal(string: "3754.76")!,
            currency: "EUR",
            date: makeDate(year: 2026, month: 2, day: 27),
            category: category,
            descriptionText: "March salary"
        )
        context.insert(original)

        // Export
        let csv = CSVExporter.exportCSV(expenses: [], incomes: [original])

        // Import into a fresh context
        let container2 = try makeContainer()
        let context2 = container2.mainContext

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        let result = try AppDataCSVImporter.importRows(rows, into: context2)

        #expect(result.incomesImported == 1)

        let imported = try context2.fetch(FetchDescriptor<Income>())
        #expect(imported.count == 1)
        #expect(imported[0].amount == original.amount)
        #expect(imported[0].currency == original.currency)
        #expect(imported[0].descriptionText == original.descriptionText)
        #expect(imported[0].category?.name == "Salary")
    }

    @Test func roundTripPreservesBaseCurrencyFields() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Other")
        context.insert(category)

        let original = Expense(
            amount: Decimal(string: "19.08")!,
            currency: "EUR",
            date: makeDate(year: 2026, month: 2, day: 26),
            category: category,
            baseCurrencyAmount: Decimal(string: "80.59")!,
            baseCurrency: "PLN"
        )
        context.insert(original)

        let csv = CSVExporter.exportCSV(expenses: [original], incomes: [])

        let container2 = try makeContainer()
        let context2 = container2.mainContext

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        _ = try AppDataCSVImporter.importRows(rows, into: context2)

        let imported = try context2.fetch(FetchDescriptor<Expense>())
        #expect(imported.count == 1)
        #expect(imported[0].baseCurrencyAmount == Decimal(string: "80.59"))
        #expect(imported[0].baseCurrency == "PLN")
    }

    @Test func roundTripWithMultipleRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let groceries = ExpenseCategory(name: "Groceries")
        let cafes = ExpenseCategory(name: "Cafes")
        let salary = IncomeCategory(name: "Salary")
        context.insert(groceries)
        context.insert(cafes)
        context.insert(salary)

        let expenses = [
            Expense(amount: 15.98, currency: "EUR", date: makeDate(year: 2026, month: 3, day: 15), category: groceries, descriptionText: "Kaufland"),
            Expense(amount: 12.84, currency: "EUR", date: makeDate(year: 2026, month: 3, day: 14), category: cafes, descriptionText: "Glovo"),
        ]
        let incomes = [
            Income(amount: 3754.76, currency: "EUR", date: makeDate(year: 2026, month: 2, day: 27), category: salary, descriptionText: "Salary"),
        ]
        for e in expenses { context.insert(e) }
        for i in incomes { context.insert(i) }

        let csv = CSVExporter.exportCSV(expenses: expenses, incomes: incomes)

        let container2 = try makeContainer()
        let context2 = container2.mainContext

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        let result = try AppDataCSVImporter.importRows(rows, into: context2)

        #expect(result.expensesImported == 2)
        #expect(result.incomesImported == 1)

        let importedExpenses = try context2.fetch(FetchDescriptor<Expense>())
        let importedIncomes = try context2.fetch(FetchDescriptor<Income>())
        #expect(importedExpenses.count == 2)
        #expect(importedIncomes.count == 1)
    }

    @Test func roundTripHandlesCommasInDescription() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = IncomeCategory(name: "Salary")
        context.insert(category)

        let original = Income(
            amount: 3754.76,
            currency: "EUR",
            date: makeDate(year: 2026, month: 2, day: 27),
            category: category,
            descriptionText: "Deel, Inc."
        )
        context.insert(original)

        let csv = CSVExporter.exportCSV(expenses: [], incomes: [original])

        let container2 = try makeContainer()
        let context2 = container2.mainContext

        let rows = AppDataCSVImporter.parseCSV(from: csv)
        _ = try AppDataCSVImporter.importRows(rows, into: context2)

        let imported = try context2.fetch(FetchDescriptor<Income>())
        #expect(imported.count == 1)
        #expect(imported[0].descriptionText == "Deel, Inc.")
    }
}
