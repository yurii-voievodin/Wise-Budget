import Foundation
import SwiftData

final class CSVExporter {

    static let header = "Type,Date,Amount,Currency,Category,Description,Destination,BaseCurrencyAmount,BaseCurrency"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Export

    static func exportCSV(expenses: [Expense], incomes: [Income]) -> String {
        var lines: [String] = [header]

        for expense in expenses.sorted(by: { $0.date < $1.date }) {
            lines.append(buildLine(
                type: "Expense",
                date: expense.date,
                amount: expense.amount,
                currency: expense.currency,
                category: expense.category?.name,
                description: expense.descriptionText,
                destination: expense.destination,
                baseCurrencyAmount: expense.baseCurrencyAmount,
                baseCurrency: expense.baseCurrency
            ))
        }

        for income in incomes.sorted(by: { $0.date < $1.date }) {
            lines.append(buildLine(
                type: "Income",
                date: income.date,
                amount: income.amount,
                currency: income.currency,
                category: income.category?.name,
                description: income.descriptionText,
                destination: income.source,
                baseCurrencyAmount: income.baseCurrencyAmount,
                baseCurrency: income.baseCurrency
            ))
        }

        return lines.joined(separator: "\n")
    }

    static func exportCSV(from context: ModelContext) throws -> String {
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let incomes = try context.fetch(FetchDescriptor<Income>())
        return exportCSV(expenses: expenses, incomes: incomes)
    }

    // MARK: - Helpers

    private static func buildLine(
        type: String,
        date: Date,
        amount: Decimal,
        currency: String,
        category: String?,
        description: String?,
        destination: String?,
        baseCurrencyAmount: Decimal?,
        baseCurrency: String?
    ) -> String {
        let fields: [String] = [
            type,
            dateFormatter.string(from: date),
            formatDecimal(amount),
            currency,
            escapeField(category ?? ""),
            escapeField(description ?? ""),
            escapeField(destination ?? ""),
            baseCurrencyAmount.map { formatDecimal($0) } ?? "",
            baseCurrency ?? ""
        ]
        return fields.joined(separator: ",")
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = ""
        formatter.decimalSeparator = "."
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func formatDecimal(_ value: Decimal) -> String {
        decimalFormatter.string(for: value) ?? "\(value)"
    }

    static func escapeField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
