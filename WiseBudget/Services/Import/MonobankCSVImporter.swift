import Foundation
import SwiftData

final class MonobankCSVImporter {

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Column Indices

    private static let dateIdx = 0
    private static let descriptionIdx = 1
    private static let mccIdx = 2
    private static let cardAmountIdx = 3
    private static let operationAmountIdx = 4
    private static let currencyIdx = 5

    // MARK: - CSV Parsing

    static func parseCSV(from url: URL) throws -> [CSVTransaction] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseCSV(from: content)
    }

    static func parseCSV(from content: String) -> [CSVTransaction] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        var transactions: [CSVTransaction] = []

        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = CSVImporter.parseCSVLine(line)
            guard fields.count > currencyIdx else { continue }

            let dateString = fields[dateIdx]
            guard let date = dateFormatter.date(from: dateString) else { continue }

            let description = fields[descriptionIdx]
            let mccString = fields[mccIdx]
            let mcc = Int(mccString) ?? 0

            let cardAmountString = fields[cardAmountIdx]
            guard let cardAmount = Decimal(string: cardAmountString) else { continue }

            let operationAmountString = fields[operationAmountIdx]
            let operationAmount = Decimal(string: operationAmountString) ?? cardAmount

            let currency = fields[currencyIdx]

            let direction: String
            let status = "COMPLETED"

            if cardAmount > 0 {
                direction = "IN"
            } else if cardAmount < 0 {
                direction = "OUT"
            } else {
                direction = "NEUTRAL"
            }

            let amount: Decimal
            let baseCurrencyAmount: Decimal?
            let baseCurrency: String?
            if currency == "UAH" {
                amount = abs(cardAmount)
                baseCurrencyAmount = nil
                baseCurrency = nil
            } else {
                amount = abs(operationAmount)
                baseCurrencyAmount = abs(cardAmount)
                baseCurrency = "UAH"
            }

            let categoryName = MCCCategoryMapping.categoryName(forMCC: mcc)

            transactions.append(CSVTransaction(
                direction: direction,
                status: status,
                date: date,
                amount: amount,
                currency: currency,
                categoryName: categoryName,
                targetName: description,
                destination: nil,
                baseCurrencyAmount: baseCurrencyAmount,
                baseCurrency: baseCurrency
            ))
        }

        return transactions
    }

    // MARK: - Import into ModelContext

    @discardableResult
    static func importTransactions(_ transactions: [CSVTransaction], into context: ModelContext) throws -> ImportResult {
        try CSVImporter.importTransactions(transactions, into: context)
    }
}
