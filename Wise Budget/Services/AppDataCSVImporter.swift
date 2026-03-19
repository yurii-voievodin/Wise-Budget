import Foundation
import SwiftData

final class AppDataCSVImporter {

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // Column indices matching CSVExporter.header
    private static let typeIdx = 0
    private static let dateIdx = 1
    private static let amountIdx = 2
    private static let currencyIdx = 3
    private static let categoryIdx = 4
    private static let descriptionIdx = 5
    private static let destinationIdx = 6
    private static let baseAmountIdx = 7
    private static let baseCurrencyIdx = 8

    // MARK: - Parsing

    struct ParsedRow {
        let type: String          // "Expense" or "Income"
        let date: Date
        let amount: Decimal
        let currency: String
        let category: String
        let description: String?
        let destination: String?
        let baseCurrencyAmount: Decimal?
        let baseCurrency: String?
    }

    static func parseCSV(from url: URL) throws -> [ParsedRow] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseCSV(from: content)
    }

    static func parseCSV(from content: String) -> [ParsedRow] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        var rows: [ParsedRow] = []

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = CSVImporter.parseCSVLine(line)
            guard fields.count > baseCurrencyIdx else { continue }

            let type = fields[typeIdx]
            guard type == "Expense" || type == "Income" else { continue }

            let dateString = fields[dateIdx]
            guard let date = dateFormatter.date(from: dateString) else { continue }

            guard let amount = Decimal(string: fields[amountIdx]) else { continue }

            let currency = fields[currencyIdx]
            let category = fields[categoryIdx]

            let description: String? = {
                let value = fields[descriptionIdx].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }()

            let destination: String? = {
                let value = fields[destinationIdx].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }()

            let baseCurrencyAmount: Decimal? = Decimal(string: fields[baseAmountIdx])

            let baseCurrency: String? = {
                let value = fields[baseCurrencyIdx].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }()

            rows.append(ParsedRow(
                type: type,
                date: date,
                amount: amount,
                currency: currency,
                category: category,
                description: description,
                destination: destination,
                baseCurrencyAmount: baseCurrencyAmount,
                baseCurrency: baseCurrency
            ))
        }

        return rows
    }

    // MARK: - Import into ModelContext

    @discardableResult
    static func importRows(_ rows: [ParsedRow], into context: ModelContext) throws -> ImportResult {
        let existingExpenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let existingIncomeCategories = try context.fetch(FetchDescriptor<IncomeCategory>())

        var expenseCategoryMap = Dictionary(uniqueKeysWithValues: existingExpenseCategories.map { ($0.name, $0) })
        var incomeCategoryMap = Dictionary(uniqueKeysWithValues: existingIncomeCategories.map { ($0.name, $0) })

        var result = ImportResult()

        for row in rows {
            if row.type == "Expense" {
                let category: ExpenseCategory
                if let existing = expenseCategoryMap[row.category] {
                    category = existing
                } else {
                    let newCategory = ExpenseCategory(name: row.category)
                    context.insert(newCategory)
                    expenseCategoryMap[row.category] = newCategory
                    category = newCategory
                }

                let expense = Expense(
                    amount: row.amount,
                    currency: row.currency,
                    date: row.date,
                    category: category,
                    descriptionText: row.description,
                    destination: row.destination,
                    baseCurrencyAmount: row.baseCurrencyAmount,
                    baseCurrency: row.baseCurrency
                )
                context.insert(expense)
                result.expensesImported += 1

            } else if row.type == "Income" {
                let category: IncomeCategory
                if let existing = incomeCategoryMap[row.category] {
                    category = existing
                } else {
                    let newCategory = IncomeCategory(name: row.category)
                    context.insert(newCategory)
                    incomeCategoryMap[row.category] = newCategory
                    category = newCategory
                }

                let income = Income(
                    amount: row.amount,
                    currency: row.currency,
                    date: row.date,
                    category: category,
                    descriptionText: row.description,
                    baseCurrencyAmount: row.baseCurrencyAmount,
                    baseCurrency: row.baseCurrency
                )
                context.insert(income)
                result.incomesImported += 1
            }
        }

        return result
    }
}
