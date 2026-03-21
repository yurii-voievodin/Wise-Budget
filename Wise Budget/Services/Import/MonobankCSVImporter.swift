import Foundation
import SwiftData

final class MonobankCSVImporter {

    // MARK: - MCC to Category Mapping

    /// Maps MCC code ranges to app expense/income category names.
    /// Monobank CSV does not include a category name, so we derive it from MCC.
    static let mccCategoryMapping: [Int: String] = {
        var map = [Int: String]()

        // Airlines
        for code in [3000, 3001, 3002, 3003, 4511] { map[code] = "Travel" }

        // Hotels / Lodging
        for code in [3500, 3501, 7011] { map[code] = "Travel" }

        // Car rental
        for code in [3351, 3352, 3353, 7512] { map[code] = "Auto" }

        // Fuel stations
        for code in [5541, 5542, 5983] { map[code] = "Auto" }

        // Auto services
        for code in [5511, 5521, 5531, 5532, 5533, 7531, 7534, 7535, 7538, 7542, 7549] { map[code] = "Auto" }

        // Public transport
        for code in [4111, 4112, 4121, 4131, 4215, 4789] { map[code] = "Auto" }

        // Groceries
        for code in [5411, 5422, 5441, 5451, 5462, 5499] { map[code] = "Groceries" }

        // Restaurants / Cafes
        for code in [5811, 5812, 5813, 5814] { map[code] = "Cafes" }

        // Utilities / Telecom
        for code in [4814, 4899, 4900] { map[code] = "Utilities" }

        // Medical
        for code in [5912, 5122, 8011, 8021, 8031, 8041, 8042, 8043, 8049, 8050, 8062, 8071, 8099] { map[code] = "Medical" }

        // Entertainment
        for code in [7832, 7841, 7911, 7922, 7929, 7932, 7933, 7941, 7991, 7993, 7994, 7995, 7996, 7998, 7999] { map[code] = "Entertainment" }

        // Shopping / Clothing / Electronics
        for code in [5137, 5139, 5611, 5621, 5631, 5641, 5651, 5655, 5661, 5691, 5699, 5732, 5733, 5734, 5735] { map[code] = "Shopping" }

        // Digital goods / Software / Subscriptions
        for code in [5815, 5816, 5817, 5818, 5262] { map[code] = "Shopping" }

        // Home / Hardware
        for code in [5200, 5211, 5231, 5251, 5261, 5712, 5713, 5714, 5718, 5719, 5722] { map[code] = "Home" }

        // Personal care
        for code in [5945, 5977, 7230, 7297, 7298] { map[code] = "Personal Items" }

        // Education
        for code in [8211, 8220, 8241, 8244, 8249, 8299] { map[code] = "Other" }

        // Insurance
        for code in [6300] { map[code] = "Other" }

        // Taxes / Government
        for code in [9211, 9222, 9311, 9399, 9402] { map[code] = "Taxes" }

        // Money transfers (peer-to-peer)
        for code in [4829, 6010, 6012, 6051] { map[code] = "Other" }

        // Financial services / Investments
        for code in [6211] { map[code] = "Other" }

        // General services
        for code in [7210, 7211, 7216, 7221, 7251, 7261, 7276, 7277, 7311, 7333, 7338, 7339, 7361, 7372, 7375, 7379, 7392, 7393, 7394, 7395, 7399] { map[code] = "Other" }

        // Misc / catch-all
        for code in [5013, 5021, 5039, 5044, 5045, 5046, 5047, 5051, 5065, 5072, 5074, 5085, 5094, 5099, 5111, 5131, 5169, 5172, 5192, 5193, 5198, 5199, 5300, 5310, 5311, 5331, 5399, 5921, 5931, 5932, 5933, 5935, 5937, 5940, 5941, 5942, 5943, 5944, 5946, 5947, 5948, 5949, 5950, 5960, 5961, 5962, 5963, 5964, 5965, 5966, 5967, 5968, 5969, 5970, 5971, 5972, 5973, 5975, 5976, 5978, 5983, 5992, 5993, 5994, 5995, 5996, 5997, 5998, 5999, 8398] { map[code] = "Other" }

        return map
    }()

    static func categoryName(forMCC mcc: Int) -> String {
        mccCategoryMapping[mcc] ?? "Other"
    }

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

            let categoryName = categoryName(forMCC: mcc)

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
