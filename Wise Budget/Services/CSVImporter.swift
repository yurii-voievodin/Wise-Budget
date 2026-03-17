import Foundation
import SwiftData

struct ImportResult {
    var expensesImported: Int = 0
    var incomesImported: Int = 0
    var skipped: Int = 0
}

struct CSVTransaction {
    let direction: String
    let status: String
    let date: Date
    let amount: Decimal
    let currency: String
    let categoryName: String
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

    static func parseCSV(from content: String) -> [CSVTransaction] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        let header = parseCSVLine(lines[0])
        guard let statusIdx = header.firstIndex(of: "Статус"),
              let directionIdx = header.firstIndex(of: "Напрямок"),
              let dateIdx = header.firstIndex(where: { $0.hasPrefix("Створено") }),
              let outAmountIdx = header.firstIndex(of: "Вихідна сума (після оплати комісії)"),
              let outCurrencyIdx = header.firstIndex(of: "Вихідна валюта"),
              let inAmountIdx = header.firstIndex(of: "Цільова сума (після оплати комісії)"),
              let inCurrencyIdx = header.firstIndex(of: "Цільова валюта"),
              let categoryIdx = header.firstIndex(of: "Категорія")
        else { return [] }

        var transactions: [CSVTransaction] = []

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = parseCSVLine(line)
            let maxRequired = max(statusIdx, directionIdx, dateIdx, outAmountIdx,
                                  outCurrencyIdx, inAmountIdx, inCurrencyIdx, categoryIdx)
            guard fields.count > maxRequired else { continue }

            let status = fields[statusIdx]
            let direction = fields[directionIdx]
            let dateString = fields[dateIdx]
            let ukrainianCategory = fields[categoryIdx]

            guard let date = dateFormatter.date(from: dateString) else { continue }

            let englishCategory = categoryMapping[ukrainianCategory] ?? ukrainianCategory

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

            transactions.append(CSVTransaction(
                direction: direction,
                status: status,
                date: date,
                amount: amount,
                currency: currency,
                categoryName: englishCategory
            ))
        }

        return transactions
    }

    // MARK: - Import into ModelContext

    @discardableResult
    static func importTransactions(_ transactions: [CSVTransaction], into context: ModelContext) throws -> ImportResult {
        let existingExpenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let existingIncomeCategories = try context.fetch(FetchDescriptor<IncomeCategory>())

        var expenseCategoryMap = Dictionary(uniqueKeysWithValues: existingExpenseCategories.map { ($0.name, $0) })
        var incomeCategoryMap = Dictionary(uniqueKeysWithValues: existingIncomeCategories.map { ($0.name, $0) })

        var result = ImportResult()

        for transaction in transactions {
            guard transaction.status == "COMPLETED", transaction.direction != "NEUTRAL" else {
                result.skipped += 1
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
                    category: category
                )
                context.insert(expense)
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
                    category: category
                )
                context.insert(income)
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
