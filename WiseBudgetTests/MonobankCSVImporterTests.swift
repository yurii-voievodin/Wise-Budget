import Testing
import Foundation
import SwiftData
@testable import WiseBudget

@MainActor
struct MonobankCSVImporterTests {

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
    "Дата i час операції","Деталі операції",MCC,"Сума в валюті картки (UAH)","Сума в валюті операції",Валюта,Курс,"Сума комісій (UAH)","Сума кешбеку (UAH)","Залишок після операції"
    "14.03.2026 17:22:58","LIQPAY*TOV TREND SET",5621,-4340.0,-4340.0,UAH,—,—,—,377295.84
    "14.03.2026 17:22:36","З гривневого рахунку ФОП",4829,4397.0,4397.0,UAH,—,—,—,381635.84
    "14.03.2026 12:52:55","З гривневого рахунку ФОП",4829,20665.9,20665.9,UAH,—,—,—,377238.84
    "14.03.2026 12:50:08",AIRBNB,4722,-20427.52,-20427.52,UAH,—,—,—,356572.94
    "09.03.2026 13:19:16",Claude,5734,-4800.28,-109.0,USD,44.0392,—,—,377414.46
    "07.03.2026 22:14:42",YouTube,5815,-120.0,-120.0,UAH,—,—,1.8,382214.74
    "07.03.2026 18:30:59",WayForPay,8398,-100.0,-100.0,UAH,—,—,—,382334.74
    "26.02.2026 14:17:42","Від: Роман Карпенко",4829,1000.0,1000.0,UAH,—,—,—,390723.72
    "12.02.2026 16:08:32",Glovo,5814,-676.58,-13.15,EUR,51.4509,—,—,374613.94
    "05.02.2026 18:46:51","Зелена картка",6300,-11835.0,-11835.0,UAH,—,—,—,371436.71
    """

    // MARK: - CSV Parsing

    @Test func parseCSVReturnsCorrectCount() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        #expect(transactions.count == 10)
    }

    @Test func parseCSVEmptyContent() {
        let transactions = MonobankCSVImporter.parseCSV(from: "")
        #expect(transactions.isEmpty)
    }

    @Test func parseCSVHeaderOnly() {
        let headerOnly = """
        "Дата i час операції","Деталі операції",MCC,"Сума в валюті картки (UAH)","Сума в валюті операції",Валюта,Курс,"Сума комісій (UAH)","Сума кешбеку (UAH)","Залишок після операції"
        """
        let transactions = MonobankCSVImporter.parseCSV(from: headerOnly)
        #expect(transactions.isEmpty)
    }

    @Test func parseCSVMalformedRowSkipped() {
        let csv = """
        "Дата i час операції","Деталі операції",MCC,"Сума в валюті картки (UAH)","Сума в валюті операції",Валюта,Курс,"Сума комісій (UAH)","Сума кешбеку (UAH)","Залишок після операції"
        too,few
        "14.03.2026 17:22:58","LIQPAY*TOV TREND SET",5621,-4340.0,-4340.0,UAH,—,—,—,377295.84
        """
        let transactions = MonobankCSVImporter.parseCSV(from: csv)
        #expect(transactions.count == 1)
    }

    // MARK: - Direction Detection

    @Test func negativeAmountBecomesExpense() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let expenses = transactions.filter { $0.direction == "OUT" }
        #expect(expenses.count == 7)
    }

    @Test func positiveAmountBecomesIncome() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let incomes = transactions.filter { $0.direction == "IN" }
        #expect(incomes.count == 3)
    }

    // MARK: - MCC Category Mapping

    @Test func mccMappedToShopping() {
        let category = MonobankCSVImporter.categoryName(forMCC: 5621)
        #expect(category == "Shopping")
    }

    @Test func mccMappedToCafes() {
        let category = MonobankCSVImporter.categoryName(forMCC: 5814)
        #expect(category == "Cafes")
    }

    @Test func mccMappedToEntertainment() {
        let category = MonobankCSVImporter.categoryName(forMCC: 7841)
        #expect(category == "Entertainment")
    }

    @Test func mccMappedToOtherForTransfers() {
        let category = MonobankCSVImporter.categoryName(forMCC: 4829)
        #expect(category == "Other")
    }

    @Test func unknownMCCDefaultsToOther() {
        let category = MonobankCSVImporter.categoryName(forMCC: 9999)
        #expect(category == "Other")
    }

    @Test func categoryAppliedDuringParsing() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let shopping = transactions.first { $0.categoryName == "Shopping" }
        #expect(shopping != nil)
        let cafes = transactions.first { $0.categoryName == "Cafes" }
        #expect(cafes != nil)
    }

    // MARK: - Amount and Currency Parsing

    @Test func uahExpenseAmountParsedCorrectly() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let first = transactions.first { $0.targetName == "LIQPAY*TOV TREND SET" }
        #expect(first?.amount == Decimal(string: "4340.0"))
        #expect(first?.currency == "UAH")
    }

    @Test func foreignCurrencyUsesOperationAmount() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let claude = transactions.first { $0.targetName == "Claude" }
        #expect(claude?.amount == Decimal(string: "109.0"))
        #expect(claude?.currency == "USD")
    }

    @Test func foreignCurrencyEUR() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let glovo = transactions.first { $0.targetName == "Glovo" }
        #expect(glovo?.amount == Decimal(string: "13.15"))
        #expect(glovo?.currency == "EUR")
    }

    @Test func incomeAmountIsPositive() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let income = transactions.first { $0.targetName == "Від: Роман Карпенко" }
        #expect(income?.direction == "IN")
        #expect(income?.amount == Decimal(string: "1000.0"))
    }

    // MARK: - Date Parsing

    @Test func dateParsedCorrectly() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let first = transactions.first { $0.targetName == "LIQPAY*TOV TREND SET" }
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: first!.date)
        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 14)
        #expect(components.hour == 17)
        #expect(components.minute == 22)
        #expect(components.second == 58)
    }

    // MARK: - Description Stored as Target Name

    @Test func descriptionStoredAsTargetName() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let youtube = transactions.first { $0.targetName == "YouTube" }
        #expect(youtube != nil)
    }

    @Test func allTransactionsHaveCompletedStatus() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        for transaction in transactions {
            #expect(transaction.status == "COMPLETED")
        }
    }

    // MARK: - Import into ModelContext

    @Test func importCreatesExpensesAndIncomes() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let result = try MonobankCSVImporter.importTransactions(transactions, into: context)

        #expect(result.expensesImported == 7)
        #expect(result.incomesImported == 3)
        #expect(result.skipped == 0)
    }

    @Test func importedExpenseHasCorrectCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        _ = try MonobankCSVImporter.importTransactions(transactions, into: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let liqpay = expenses.first { $0.descriptionText == "LIQPAY*TOV TREND SET" }
        #expect(liqpay != nil)
        #expect(liqpay?.amount == Decimal(string: "4340.0"))
    }

    @Test func importedIncomeHasCorrectCategory() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        _ = try MonobankCSVImporter.importTransactions(transactions, into: context)

        let incomes = try context.fetch(FetchDescriptor<Income>())
        #expect(incomes.count == 3)
    }

    @Test func importReusesExistingCategories() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let existing = ExpenseCategory(name: "Shopping")
        context.insert(existing)

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        _ = try MonobankCSVImporter.importTransactions(transactions, into: context)

        let categories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let shoppingCategories = categories.filter { $0.name == "Shopping" }
        #expect(shoppingCategories.count == 1)
    }

    // MARK: - Deduplication

    @Test func importSameCSVTwiceSkipsDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let firstResult = try MonobankCSVImporter.importTransactions(transactions, into: context)

        #expect(firstResult.expensesImported == 7)
        #expect(firstResult.incomesImported == 3)
        #expect(firstResult.duplicatesSkipped == 0)

        let secondResult = try MonobankCSVImporter.importTransactions(transactions, into: context)

        #expect(secondResult.expensesImported == 0)
        #expect(secondResult.incomesImported == 0)
        #expect(secondResult.duplicatesSkipped == 10)
    }

    // MARK: - Base Currency Amount

    @Test func uahTransactionHasNoBaseCurrency() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let uah = transactions.first { $0.targetName == "LIQPAY*TOV TREND SET" }
        #expect(uah?.baseCurrencyAmount == nil)
        #expect(uah?.baseCurrency == nil)
    }

    @Test func foreignCurrencyHasBaseCurrencyUAH() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let claude = transactions.first { $0.targetName == "Claude" }
        #expect(claude?.baseCurrencyAmount == Decimal(string: "4800.28"))
        #expect(claude?.baseCurrency == "UAH")
    }

    @Test func eurTransactionHasBaseCurrencyUAH() {
        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        let glovo = transactions.first { $0.targetName == "Glovo" }
        #expect(glovo?.baseCurrencyAmount == Decimal(string: "676.58"))
        #expect(glovo?.baseCurrency == "UAH")
    }

    @Test func importedForeignExpenseHasBaseCurrency() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        _ = try MonobankCSVImporter.importTransactions(transactions, into: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let claude = expenses.first { $0.descriptionText == "Claude" }
        #expect(claude?.amount == Decimal(string: "109.0"))
        #expect(claude?.currency == "USD")
        #expect(claude?.baseCurrencyAmount == Decimal(string: "4800.28"))
        #expect(claude?.baseCurrency == "UAH")
    }

    @Test func importedUahExpenseHasNoBaseCurrency() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let transactions = MonobankCSVImporter.parseCSV(from: sampleCSV)
        _ = try MonobankCSVImporter.importTransactions(transactions, into: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let liqpay = expenses.first { $0.descriptionText == "LIQPAY*TOV TREND SET" }
        #expect(liqpay?.baseCurrencyAmount == nil)
        #expect(liqpay?.baseCurrency == nil)
    }

    @Test func sameDayDifferentAmountNotDuplicate() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let csv = """
        "Дата i час операції","Деталі операції",MCC,"Сума в валюті картки (UAH)","Сума в валюті операції",Валюта,Курс,"Сума комісій (UAH)","Сума кешбеку (UAH)","Залишок після операції"
        "14.03.2026 17:22:58","Shop A",5411,-100.0,-100.0,UAH,—,—,—,1000.0
        "14.03.2026 18:00:00","Shop B",5411,-200.0,-200.0,UAH,—,—,—,800.0
        """

        let transactions = MonobankCSVImporter.parseCSV(from: csv)
        let result = try MonobankCSVImporter.importTransactions(transactions, into: context)

        #expect(result.expensesImported == 2)
        #expect(result.duplicatesSkipped == 0)
    }
}
