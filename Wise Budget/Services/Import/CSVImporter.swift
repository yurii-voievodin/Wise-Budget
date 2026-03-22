import Foundation
import SwiftData

struct ImportResult {
    var expensesImported: Int = 0
    var incomesImported: Int = 0
    var skipped: Int = 0
    var duplicatesSkipped: Int = 0
}

struct CSVTransaction {
    let direction: String
    let status: String
    let date: Date
    let amount: Decimal
    let currency: String
    let categoryName: String
    let targetName: String?
    let destination: String?
    let baseCurrencyAmount: Decimal?
    let baseCurrency: String?
    let externalId: String?

    init(direction: String, status: String, date: Date, amount: Decimal, currency: String, categoryName: String, targetName: String?, destination: String?, baseCurrencyAmount: Decimal? = nil, baseCurrency: String? = nil, externalId: String? = nil) {
        self.direction = direction
        self.status = status
        self.date = date
        self.amount = amount
        self.currency = currency
        self.categoryName = categoryName
        self.targetName = targetName
        self.destination = destination
        self.baseCurrencyAmount = baseCurrencyAmount
        self.baseCurrency = baseCurrency
        self.externalId = externalId
    }
}

final class CSVImporter {

    static let categoryMapping: [String: String] = [
        "Продукти харчування": "Groceries",
        "Ресторани": "Cafes",
        "Рахунки": "Utilities",
        "Транспорт": "Auto",
        "Магазини": "Shopping",
        "Житло": "Home",
        "Засоби гігієни": "Personal Items",
        "Зарплата": "Salary",
        "Заощадження": "Savings",
        "Загальне": "Other",
    ]

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - CSV Parsing

    static func parseCSV(from url: URL) throws -> [CSVTransaction] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseCSV(from: content)
    }

    // Column indices matching the standard Wise CSV export layout
    private static let statusIdx = 1
    private static let directionIdx = 2
    private static let dateIdx = 3
    private static let outAmountIdx = 10
    private static let outCurrencyIdx = 11
    private static let targetNameIdx = 12
    private static let inAmountIdx = 13
    private static let inCurrencyIdx = 14
    private static let destinationIdx = 16
    private static let categoryIdx = 19

    static func parseCSV(from content: String) -> [CSVTransaction] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        var transactions: [CSVTransaction] = []

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = parseCSVLine(line)
            guard fields.count > categoryIdx else { continue }

            let status = fields[statusIdx]
            let direction = fields[directionIdx]
            let dateString = fields[dateIdx]
            let rawCategory = fields[categoryIdx]

            guard let date = dateFormatter.date(from: dateString) else { continue }

            let categoryName = categoryMapping[rawCategory] ?? rawCategory

            let amountString: String
            let currency: String
            if direction == "IN" {
                amountString = fields[inAmountIdx]
                currency = fields[inCurrencyIdx]
            } else {
                amountString = fields[outAmountIdx]
                currency = fields[outCurrencyIdx]
            }

            guard let amount = Decimal(string: amountString) else { continue }

            let targetName: String?
            if fields.count > targetNameIdx {
                let value = fields[targetNameIdx].trimmingCharacters(in: .whitespaces)
                targetName = value.isEmpty ? nil : value
            } else {
                targetName = nil
            }

            let destination: String?
            if fields.count > destinationIdx {
                let value = fields[destinationIdx].trimmingCharacters(in: .whitespaces)
                destination = value.isEmpty ? nil : value
            } else {
                destination = nil
            }

            transactions.append(CSVTransaction(
                direction: direction,
                status: status,
                date: date,
                amount: amount,
                currency: currency,
                categoryName: categoryName,
                targetName: targetName,
                destination: destination
            ))
        }

        return transactions
    }

    private struct TransactionKey: Hashable {
        let day: Date
        let currency: String
        let amount: Decimal
    }

    // MARK: - Import into ModelContext

    @discardableResult
    static func importTransactions(_ transactions: [CSVTransaction], into context: ModelContext) throws -> ImportResult {
        let existingExpenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let existingIncomeCategories = try context.fetch(FetchDescriptor<IncomeCategory>())

        var expenseCategoryMap = Dictionary(uniqueKeysWithValues: existingExpenseCategories.map { ($0.name, $0) })
        var incomeCategoryMap = Dictionary(uniqueKeysWithValues: existingIncomeCategories.map { ($0.name, $0) })

        let existingExpenses = try context.fetch(FetchDescriptor<Expense>())
        let existingIncomes = try context.fetch(FetchDescriptor<Income>())

        // Primary dedup: external IDs from bank APIs
        var existingExternalIds = Set<String>()
        for expense in existingExpenses {
            if let id = expense.externalId { existingExternalIds.insert(id) }
        }
        for income in existingIncomes {
            if let id = income.externalId { existingExternalIds.insert(id) }
        }

        // Fallback dedup: date + amount + currency (for manually created or CSV-imported transactions)
        var existingKeys = Set<TransactionKey>()
        let calendar = Calendar.current
        for expense in existingExpenses where expense.externalId == nil {
            existingKeys.insert(TransactionKey(
                day: calendar.startOfDay(for: expense.date),
                currency: expense.currency,
                amount: expense.amount
            ))
        }
        for income in existingIncomes where income.externalId == nil {
            existingKeys.insert(TransactionKey(
                day: calendar.startOfDay(for: income.date),
                currency: income.currency,
                amount: income.amount
            ))
        }

        var result = ImportResult()

        for transaction in transactions {
            guard transaction.status == "COMPLETED", transaction.direction != "NEUTRAL" else {
                result.skipped += 1
                continue
            }

            // Check external ID first (most reliable)
            if let externalId = transaction.externalId, existingExternalIds.contains(externalId) {
                result.duplicatesSkipped += 1
                continue
            }

            // Fallback: check by date + amount + currency (only against records without externalId)
            let key = TransactionKey(
                day: calendar.startOfDay(for: transaction.date),
                currency: transaction.currency,
                amount: transaction.amount
            )
            if transaction.externalId == nil, existingKeys.contains(key) {
                result.duplicatesSkipped += 1
                continue
            }

            if transaction.direction == "OUT" {
                let category: ExpenseCategory
                if let existing = expenseCategoryMap[transaction.categoryName] {
                    category = existing
                } else {
                    let newCategory = ExpenseCategory(name: transaction.categoryName)
                    context.insert(newCategory)
                    expenseCategoryMap[transaction.categoryName] = newCategory
                    category = newCategory
                }

                let expense = Expense(
                    amount: transaction.amount,
                    currency: transaction.currency,
                    date: transaction.date,
                    category: category,
                    descriptionText: transaction.targetName,
                    destination: transaction.destination,
                    baseCurrencyAmount: transaction.baseCurrencyAmount,
                    baseCurrency: transaction.baseCurrency,
                    externalId: transaction.externalId
                )
                context.insert(expense)
                if let externalId = transaction.externalId {
                    existingExternalIds.insert(externalId)
                } else {
                    existingKeys.insert(key)
                }
                result.expensesImported += 1

            } else if transaction.direction == "IN" {
                let category: IncomeCategory
                if let existing = incomeCategoryMap[transaction.categoryName] {
                    category = existing
                } else {
                    let newCategory = IncomeCategory(name: transaction.categoryName)
                    context.insert(newCategory)
                    incomeCategoryMap[transaction.categoryName] = newCategory
                    category = newCategory
                }

                let income = Income(
                    amount: transaction.amount,
                    currency: transaction.currency,
                    date: transaction.date,
                    category: category,
                    descriptionText: transaction.targetName,
                    baseCurrencyAmount: transaction.baseCurrencyAmount,
                    baseCurrency: transaction.baseCurrency,
                    externalId: transaction.externalId
                )
                context.insert(income)
                if let externalId = transaction.externalId {
                    existingExternalIds.insert(externalId)
                } else {
                    existingKeys.insert(key)
                }
                result.incomesImported += 1

            } else {
                result.skipped += 1
            }
        }

        return result
    }

    // MARK: - CSV Line Parser (handles quoted fields)

    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)

        return fields
    }
}
