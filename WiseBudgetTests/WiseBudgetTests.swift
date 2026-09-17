import Testing
import Foundation
import SwiftData
@testable import WiseBudget

struct WiseBudgetTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self])
        let config = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private let sampleCSV = """
    Ідентифікатор,Статус,Напрямок,Створено:,Завершено,Комісія з вихідної суми,Валюта комісії з вихідної суми,Комісія із цільової суми,Валюта комісії із цільової суми,Назва джерела,Вихідна сума (після оплати комісії),Вихідна валюта,Назва цілі,Цільова сума (після оплати комісії),Цільова валюта,Обмінний курс,Призначення,Масові платежі,Хто створив:,Категорія,Примітка
    CARD-001,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Продукти харчування,
    CARD-002,COMPLETED,OUT,2026-03-14 12:00:00,2026-03-14 12:00:00,0.00,EUR,,,Yurii,12.84,EUR,Glovo,12.84,EUR,1.0,,,Yurii,Ресторани,
    TRANSFER-001,COMPLETED,IN,2026-02-27 08:33:53,2026-02-27 08:34:05,,,,,"Deel, Inc.",3754.76,EUR,Yurii,3754.76,EUR,1,Alesium Ltd,,,Зарплата,
    BALANCE-001,COMPLETED,NEUTRAL,2026-02-27 08:35:58,2026-02-27 08:35:58,0.00,EUR,,,Yurii,2000.00,EUR,Yurii,2000.00,EUR,1.0,,,Yurii,Заощадження,
    CARD-003,REFUNDED,IN,2026-02-25 00:00:00,2026-02-25 00:00:00,,,,,"Urbo City",0.10,EUR,Yurii,0.10,EUR,1,,,Yurii,Транспорт,
    CARD-004,REFUNDED,OUT,2026-02-21 09:15:15,2026-02-21 09:15:15,,,,Yurii,0.20,EUR,ePay.bg,0.20,EUR,1,,,Yurii,Магазини,
    CARD-005,COMPLETED,OUT,2026-03-02 11:34:14,2026-03-02 11:34:14,0.00,EUR,,,Yurii,25.50,EUR,Barbershop,25.50,EUR,1.0,,,Yurii,Засоби гігієни,
    CARD-006,COMPLETED,OUT,2026-03-04 08:27:42,2026-03-04 08:27:56,0.00,EUR,,,Yurii,235.0,EUR,Landlord,235.0,EUR,1.0,Rent,,,Житло,
    CARD-007,COMPLETED,OUT,2026-03-16 13:42:50,2026-03-16 13:42:50,0.00,EUR,,,Yurii,13.81,EUR,Vivacom,13.81,EUR,1.0,,,Yurii,Рахунки,
    CARD-008,COMPLETED,OUT,2026-02-26 11:18:55,2026-02-26 11:20:01,0.92,EUR,,,Yurii,19.08,EUR,Yurii,80.59,PLN,4.22355,transfer,,,Загальне,
    CARD-009,COMPLETED,OUT,2026-03-15 08:31:16,2026-03-15 08:31:16,0.00,EUR,,,Yurii,7.16,EUR,IKEA,7.16,EUR,1.0,,,Yurii,Магазини,
    """

    // MARK: - CSV Parsing

    @Test func parseCSVReturnsCorrectCount() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        #expect(transactions.count == 11)
    }

    @Test func parseCSVEmptyContent() {
        let transactions = CSVImporter.parseCSV(from: "")
        #expect(transactions.isEmpty)
    }

    @Test func parseCSVHeaderOnly() {
        let headerOnly = "Ідентифікатор,Статус,Напрямок,Створено:,Завершено,Комісія з вихідної суми,Валюта комісії з вихідної суми,Комісія із цільової суми,Валюта комісії із цільової суми,Назва джерела,Вихідна сума (після оплати комісії),Вихідна валюта,Назва цілі,Цільова сума (після оплати комісії),Цільова валюта,Обмінний курс,Призначення,Масові платежі,Хто створив:,Категорія,Примітка"
        let transactions = CSVImporter.parseCSV(from: headerOnly)
        #expect(transactions.isEmpty)
    }

    @Test func parseCSVMalformedRowSkipped() {
        let csv = """
        Ідентифікатор,Статус,Напрямок,Створено:,Завершено,Комісія з вихідної суми,Валюта комісії з вихідної суми,Комісія із цільової суми,Валюта комісії із цільової суми,Назва джерела,Вихідна сума (після оплати комісії),Вихідна валюта,Назва цілі,Цільова сума (після оплати комісії),Цільова валюта,Обмінний курс,Призначення,Масові платежі,Хто створив:,Категорія,Примітка
        too,few,fields
        CARD-001,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Продукти харчування,
        """
        let transactions = CSVImporter.parseCSV(from: csv)
        #expect(transactions.count == 1)
    }

    // MARK: - Direction Filtering

    @Test func outCompletedBecomesExpense() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let outCompleted = transactions.filter { $0.direction == "OUT" && $0.status == "COMPLETED" }
        #expect(outCompleted.count == 7)
    }

    @Test func inCompletedBecomesIncome() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let inCompleted = transactions.filter { $0.direction == "IN" && $0.status == "COMPLETED" }
        #expect(inCompleted.count == 1)
    }

    @Test func neutralTransactionsParsed() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let neutral = transactions.filter { $0.direction == "NEUTRAL" }
        #expect(neutral.count == 1)
    }

    @Test func refundedTransactionsParsed() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let refunded = transactions.filter { $0.status == "REFUNDED" }
        #expect(refunded.count == 2)
    }

    // MARK: - Category Mapping

    @Test(arguments: [
        ("Продукти харчування", "Groceries"),
        ("Ресторани", "Cafes"),
        ("Рахунки", "Utilities"),
        ("Транспорт", "Auto"),
        ("Магазини", "Shopping"),
        ("Житло", "Home"),
        ("Засоби гігієни", "Personal Items"),
        ("Зарплата", "Salary"),
        ("Заощадження", "Other"),
        ("Загальне", "Other"),
    ])
    func categoryMappingExists(ukrainian: String, english: String) {
        #expect(CSVImporter.categoryMapping[ukrainian] == english)
    }

    @Test func categoryMappingAppliedDuringParsing() throws {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        _ = try #require(transactions.first { $0.categoryName == "Groceries" })
        _ = try #require(transactions.first { $0.categoryName == "Cafes" })
        _ = try #require(transactions.first { $0.categoryName == "Salary" })
    }

    // MARK: - Amount and Currency Parsing

    @Test func expenseAmountParsedCorrectly() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let first = transactions.first { $0.categoryName == "Groceries" }
        #expect(first?.amount == Decimal(string: "15.98"))
        #expect(first?.currency == "EUR")
    }

    @Test func incomeUsesTargetAmount() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let income = transactions.first { $0.direction == "IN" && $0.status == "COMPLETED" }
        #expect(income?.amount == Decimal(string: "3754.76"))
        #expect(income?.currency == "EUR")
    }

    @Test func differentCurrencyParsed() {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let pln = transactions.first { $0.categoryName == "Other" && $0.direction == "OUT" }
        #expect(pln?.amount == Decimal(string: "19.08"))
        #expect(pln?.currency == "EUR")
    }

    // MARK: - Date Parsing

    @Test func dateParsedCorrectly() throws {
        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let first = try #require(transactions.first { $0.categoryName == "Groceries" }, "Expected a Groceries transaction")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: first.date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 15)
        #expect(components.hour == 10)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    // MARK: - Import into ModelContext

    @Test func importCreatesExpensesAndIncomes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let result = try CSVImporter.importTransactions(transactions, into: context)

        #expect(result.expensesImported == 7)
        #expect(result.incomesImported == 1)
        #expect(result.skipped == 3)
    }

    @Test func importSkipsNeutralAndRefunded() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let result = try CSVImporter.importTransactions(transactions, into: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let incomes = try context.fetch(FetchDescriptor<Income>())
        #expect(expenses.count == 7)
        #expect(incomes.count == 1)
        #expect(result.skipped == 3)
    }

    @Test func importReusesExistingCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ExpenseCategory(name: "Groceries")
        context.insert(existing)

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        _ = try CSVImporter.importTransactions(transactions, into: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let groceriesCategories = categories.filter { $0.name == "Groceries" }
        #expect(groceriesCategories.count == 1)
    }

    @Test func importCreatesNewCategoriesWhenMissing() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        _ = try CSVImporter.importTransactions(transactions, into: context)

        let expenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let names = Set(expenseCategories.map(\.name))
        #expect(names.contains("Shopping"))
    }

    @Test func importedExpenseHasCorrectCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        _ = try CSVImporter.importTransactions(transactions, into: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let homeExpense = expenses.first { $0.category?.name == "Home" }
        #expect(homeExpense != nil)
        #expect(homeExpense?.amount == Decimal(string: "235.0"))
    }

    @Test func importedIncomeHasCorrectCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        _ = try CSVImporter.importTransactions(transactions, into: context)

        let incomes = try context.fetch(FetchDescriptor<Income>())
        #expect(incomes.count == 1)
        #expect(incomes.first?.category?.name == "Salary")
        #expect(incomes.first?.amount == Decimal(string: "3754.76"))
    }

    @Test func deleteAllExpensesKeepsCategoriesAndClearsInverseRelationships() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Groceries")
        let expense = Expense(amount: 10, currency: "EUR", category: category)
        context.insert(category)
        context.insert(expense)
        try context.save()

        try context.deleteAll(Expense.self)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        #expect(expenses.isEmpty)
        #expect(categories.count == 1)
        #expect(categories.first?.expenses.isEmpty == true)
    }

    @Test func deleteAllIncomesKeepsCategoriesAndClearsInverseRelationships() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let category = IncomeCategory(name: "Salary")
        let income = Income(amount: 10, currency: "EUR", category: category)
        context.insert(category)
        context.insert(income)
        try context.save()

        try context.deleteAll(Income.self)

        let incomes = try context.fetch(FetchDescriptor<Income>())
        let categories = try context.fetch(FetchDescriptor<IncomeCategory>())
        #expect(incomes.isEmpty)
        #expect(categories.count == 1)
        #expect(categories.first?.incomes.isEmpty == true)
    }

    // MARK: - Deduplication

    @Test func importSameCSVTwiceSkipsDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = CSVImporter.parseCSV(from: sampleCSV)
        let firstResult = try CSVImporter.importTransactions(transactions, into: context)

        #expect(firstResult.expensesImported == 7)
        #expect(firstResult.incomesImported == 1)
        #expect(firstResult.duplicatesSkipped == 0)

        let secondResult = try CSVImporter.importTransactions(transactions, into: context)

        #expect(secondResult.expensesImported == 0)
        #expect(secondResult.incomesImported == 0)
        #expect(secondResult.duplicatesSkipped == 8)
    }

    @Test func sameDayDifferentAmountNotDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let csv = """
        Ідентифікатор,Статус,Напрямок,Створено:,Завершено,Комісія з вихідної суми,Валюта комісії з вихідної суми,Комісія із цільової суми,Валюта комісії із цільової суми,Назва джерела,Вихідна сума (після оплати комісії),Вихідна валюта,Назва цілі,Цільова сума (після оплати комісії),Цільова валюта,Обмінний курс,Призначення,Масові платежі,Хто створив:,Категорія,Примітка
        CARD-001,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Продукти харчування,
        CARD-002,COMPLETED,OUT,2026-03-15 12:00:00,2026-03-15 12:00:00,0.00,EUR,,,Yurii,25.00,EUR,Kaufland,25.00,EUR,1.0,,,Yurii,Продукти харчування,
        """

        let transactions = CSVImporter.parseCSV(from: csv)
        let result = try CSVImporter.importTransactions(transactions, into: context)

        #expect(result.expensesImported == 2)
        #expect(result.duplicatesSkipped == 0)
    }

    @Test func sameAmountDifferentDayNotDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let csv = """
        Ідентифікатор,Статус,Напрямок,Створено:,Завершено,Комісія з вихідної суми,Валюта комісії з вихідної суми,Комісія із цільової суми,Валюта комісії із цільової суми,Назва джерела,Вихідна сума (після оплати комісії),Вихідна валюта,Назва цілі,Цільова сума (після оплати комісії),Цільова валюта,Обмінний курс,Призначення,Масові платежі,Хто створив:,Категорія,Примітка
        CARD-001,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Продукти харчування,
        CARD-002,COMPLETED,OUT,2026-03-16 10:00:00,2026-03-16 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Продукти харчування,
        """

        let transactions = CSVImporter.parseCSV(from: csv)
        let result = try CSVImporter.importTransactions(transactions, into: context)

        #expect(result.expensesImported == 2)
        #expect(result.duplicatesSkipped == 0)
    }

    // MARK: - English Header Support

    private let englishCSV = """
    TransferWise ID,Status,Direction,Created,Finished,Source fee amount,Source fee currency,Target fee amount,Target fee currency,Source name,Source amount (after fees),Source currency,Target name,Target amount (after fees),Target currency,Exchange rate,Reference,Batch,Created by,Category,Note
    CARD-001,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,15.98,EUR,Kaufland,15.98,EUR,1.0,,,Yurii,Groceries,
    TRANSFER-001,COMPLETED,IN,2026-02-27 08:33:53,2026-02-27 08:34:05,,,,,\"Deel, Inc.\",3754.76,EUR,Yurii,3754.76,EUR,1,Alesium Ltd,,,Salary,
    """

    @Test func parseCSVWithEnglishHeaders() {
        let transactions = CSVImporter.parseCSV(from: englishCSV)
        #expect(transactions.count == 2)
    }

    @Test func englishHeaderExpenseParsedCorrectly() {
        let transactions = CSVImporter.parseCSV(from: englishCSV)
        let expense = transactions.first { $0.direction == "OUT" }
        #expect(expense?.status == "COMPLETED")
        #expect(expense?.amount == Decimal(string: "15.98"))
        #expect(expense?.currency == "EUR")
        #expect(expense?.categoryName == "Groceries")
        #expect(expense?.targetName == "Kaufland")
    }

    @Test func englishHeaderIncomeParsedCorrectly() {
        let transactions = CSVImporter.parseCSV(from: englishCSV)
        let income = transactions.first { $0.direction == "IN" }
        #expect(income?.status == "COMPLETED")
        #expect(income?.amount == Decimal(string: "3754.76"))
        #expect(income?.currency == "EUR")
        #expect(income?.categoryName == "Salary")
        #expect(income?.destination == "Alesium Ltd")
    }

    @Test func parseCSVWithUnknownLanguageFallsBackToColumnIndex() {
        let csv = """
        ID,Стан,Бік,Дата,Кінець,Ком1,Вал1,Ком2,Вал2,Джерело,10.00,EUR,Магазин,10.00,EUR,1.0,Платіж,,Автор,Food,
        CARD-X,COMPLETED,OUT,2026-03-15 10:00:00,2026-03-15 10:00:00,0.00,EUR,,,Yurii,20.50,EUR,Shop,20.50,EUR,1.0,,,Yurii,Food,
        """
        let transactions = CSVImporter.parseCSV(from: csv)
        #expect(transactions.count == 1)
        #expect(transactions.first?.amount == Decimal(string: "20.50"))
        #expect(transactions.first?.currency == "EUR")
        #expect(transactions.first?.categoryName == "Food")
    }

    // MARK: - CSV Line Parser

    @Test func parseCSVLineHandlesQuotedFields() {
        let line = #""CARD-001",COMPLETED,OUT,"2026-03-15 10:00:00""#
        let fields = CSVImporter.parseCSVLine(line)
        #expect(fields.count == 4)
        #expect(fields[0] == "CARD-001")
        #expect(fields[3] == "2026-03-15 10:00:00")
    }

    @Test func parseCSVLineHandlesEmptyFields() {
        let line = "a,,b,"
        let fields = CSVImporter.parseCSVLine(line)
        #expect(fields.count == 4)
        #expect(fields[1] == "")
        #expect(fields[3] == "")
    }
}
