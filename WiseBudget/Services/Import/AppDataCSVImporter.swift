import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "AppDataCSVImporter")

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

    /// Stable fingerprint of a row used to detect re-imports of the same CSV.
    /// Includes everything that meaningfully identifies a transaction: type,
    /// date, amount, currency, category name, description, destination.
    /// Two rows with the same fingerprint are treated as the same transaction.
    private static func fingerprint(type: String, date: Date, amount: Decimal,
                                     currency: String, category: String,
                                     description: String?, destination: String?) -> String {
        let dateStr = dateFormatter.string(from: date)
        let amountStr = NSDecimalNumber(decimal: amount).stringValue
        return "\(type)|\(dateStr)|\(amountStr)|\(currency)|\(category)|\(description ?? "")|\(destination ?? "")"
    }

    @discardableResult
    static func importRows(_ rows: [ParsedRow], into context: ModelContext) throws -> ImportResult {
        logger.info("Starting import of \(rows.count) parsed rows")

        let existingExpenseCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let existingIncomeCategories = try context.fetch(FetchDescriptor<IncomeCategory>())

        var expenseCategoryMap = Dictionary(uniqueKeysWithValues: existingExpenseCategories.map { ($0.name, $0) })
        var incomeCategoryMap = Dictionary(uniqueKeysWithValues: existingIncomeCategories.map { ($0.name, $0) })

        // Build fingerprint set of existing transactions so a re-import of the
        // same CSV is idempotent. Category is part of the fingerprint, so a
        // category rename/alias change will NOT match — re-import after rename
        // would create duplicates under the new name.
        var existingFingerprints = Set<String>()
        let existingExpenses = try context.fetch(FetchDescriptor<Expense>())
        for e in existingExpenses {
            existingFingerprints.insert(fingerprint(
                type: "Expense", date: e.date, amount: e.amount, currency: e.currency,
                category: e.category?.name ?? "", description: e.descriptionText,
                destination: e.destination
            ))
        }
        let existingIncomes = try context.fetch(FetchDescriptor<Income>())
        for i in existingIncomes {
            existingFingerprints.insert(fingerprint(
                type: "Income", date: i.date, amount: i.amount, currency: i.currency,
                category: i.category?.name ?? "", description: i.descriptionText,
                destination: i.source
            ))
        }

        var result = ImportResult()
        var newExpenseCategories: [String] = []
        var newIncomeCategories: [String] = []
        var expenseCounts: [String: Int] = [:]
        var incomeCounts: [String: Int] = [:]
        var expenseTotals: [String: Decimal] = [:]
        var incomeTotals: [String: Decimal] = [:]

        for row in rows {
            let fp = fingerprint(
                type: row.type, date: row.date, amount: row.amount, currency: row.currency,
                category: row.category, description: row.description, destination: row.destination
            )
            if existingFingerprints.contains(fp) {
                result.duplicatesSkipped += 1
                continue
            }
            existingFingerprints.insert(fp)

            if row.type == "Expense" {
                let category: ExpenseCategory
                if let existing = expenseCategoryMap[row.category] {
                    category = existing
                } else {
                    let newCategory = ExpenseCategory(name: row.category)
                    context.insert(newCategory)
                    expenseCategoryMap[row.category] = newCategory
                    newExpenseCategories.append(row.category)
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
                expenseCounts[row.category, default: 0] += 1
                expenseTotals[row.category, default: 0] += row.amount

            } else if row.type == "Income" {
                let category: IncomeCategory
                if let existing = incomeCategoryMap[row.category] {
                    category = existing
                } else {
                    let newCategory = IncomeCategory(name: row.category)
                    context.insert(newCategory)
                    incomeCategoryMap[row.category] = newCategory
                    newIncomeCategories.append(row.category)
                    category = newCategory
                }

                let income = Income(
                    amount: row.amount,
                    currency: row.currency,
                    date: row.date,
                    category: category,
                    descriptionText: row.description,
                    source: row.destination,
                    baseCurrencyAmount: row.baseCurrencyAmount,
                    baseCurrency: row.baseCurrency
                )
                context.insert(income)
                result.incomesImported += 1
                incomeCounts[row.category, default: 0] += 1
                incomeTotals[row.category, default: 0] += row.amount
            }
        }

        logImportSummary(
            result: result,
            newExpenseCategories: newExpenseCategories,
            newIncomeCategories: newIncomeCategories,
            expenseCounts: expenseCounts,
            incomeCounts: incomeCounts,
            expenseTotals: expenseTotals,
            incomeTotals: incomeTotals
        )

        return result
    }

    private static func logImportSummary(
        result: ImportResult,
        newExpenseCategories: [String],
        newIncomeCategories: [String],
        expenseCounts: [String: Int],
        incomeCounts: [String: Int],
        expenseTotals: [String: Decimal],
        incomeTotals: [String: Decimal]
    ) {
        logger.info("Imported \(result.expensesImported) expenses, \(result.incomesImported) incomes")
        if !newExpenseCategories.isEmpty {
            logger.info("New ExpenseCategory created (\(newExpenseCategories.count)): \(newExpenseCategories.joined(separator: ", "))")
        }
        if !newIncomeCategories.isEmpty {
            logger.info("New IncomeCategory created (\(newIncomeCategories.count)): \(newIncomeCategories.joined(separator: ", "))")
        }
        for (cat, n) in expenseCounts.sorted(by: { $0.value > $1.value }) {
            let total = expenseTotals[cat] ?? 0
            logger.info("  Expense [\(cat)]: \(n) rows, total \(total.description)")
        }
        for (cat, n) in incomeCounts.sorted(by: { $0.value > $1.value }) {
            let total = incomeTotals[cat] ?? 0
            logger.info("  Income  [\(cat)]: \(n) rows, total \(total.description)")
        }
    }
}
