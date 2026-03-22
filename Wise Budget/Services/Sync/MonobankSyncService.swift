import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankSync")

final class MonobankSyncService {

    /// Maximum date range per Monobank statement request (31 days).
    private static let maxWindowSeconds: TimeInterval = 31 * 24 * 60 * 60

    /// Delay between consecutive API calls to respect rate limits.
    private static let rateLimitDelay: TimeInterval = 1.0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Syncs Monobank transactions into the given model context.
    /// Fetches statements from the last sync date (or start of current month) until now.
    static func sync(context: ModelContext, lastSyncTimestamp: Double?) async throws -> ImportResult {
        logger.info("sync started")

        guard let token = KeychainHelper.loadToken(service: KeychainHelper.monobankService) else {
            logger.warning("sync aborted: no token in Keychain")
            throw MonobankAPIError.noToken
        }

        let client = MonobankAPIClient(token: token)

        // Fetch account list
        logger.debug("fetching client info...")
        let clientInfo = try await client.fetchClientInfo()
        let selectedIds = MonobankConnectSheet.loadSelectedAccountIds()
        let accountsToSync: [MonobankAccount]
        if selectedIds.isEmpty {
            accountsToSync = clientInfo.accounts
            logger.info("no account filter set, syncing all \(clientInfo.accounts.count) accounts")
        } else {
            accountsToSync = clientInfo.accounts.filter { selectedIds.contains($0.id) }
            logger.info("syncing \(accountsToSync.count) of \(clientInfo.accounts.count) accounts (filtered by selection)")
        }

        // Determine the start date for fetching
        let fromDate: Date
        if let lastSync = lastSyncTimestamp, lastSync > 0 {
            fromDate = Date(timeIntervalSince1970: lastSync)
            logger.debug("sync from last sync: \(dateFormatter.string(from: fromDate))")
        } else {
            // Default: start of current month
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: Date())
            fromDate = calendar.date(from: components) ?? Date()
            logger.debug("sync from start of month: \(dateFormatter.string(from: fromDate))")
        }
        let toDate = Date()
        logger.debug("sync to: \(dateFormatter.string(from: toDate))")

        var allTransactions: [CSVTransaction] = []

        for account in accountsToSync {
            let currency = MonobankAPIClient.currencyString(for: account.currencyCode)
            logger.debug("processing account \(account.id, privacy: .private) (\(currency))")

            // Split into 31-day windows
            let windows = dateWindows(from: fromDate, to: toDate)
            logger.debug("date range split into \(windows.count) window(s)")

            for (windowStart, windowEnd) in windows {
                logger.debug("fetching statements: \(dateFormatter.string(from: windowStart)) -> \(dateFormatter.string(from: windowEnd))")

                let statements = try await client.fetchStatements(
                    accountId: account.id,
                    from: windowStart,
                    to: windowEnd
                )

                let transactions = statements.compactMap { statement -> CSVTransaction? in
                    convertStatement(statement, accountCurrency: currency)
                }
                allTransactions.append(contentsOf: transactions)
                logger.debug("fetched \(statements.count) statements, \(transactions.count) converted")

                // Respect rate limits between calls
                if windows.count > 1 {
                    logger.debug("rate limit delay between windows...")
                    try await Task.sleep(nanoseconds: UInt64(rateLimitDelay * 1_000_000_000))
                }
            }

            // Small delay between accounts
            if accountsToSync.count > 1 {
                logger.debug("rate limit delay between accounts...")
                try await Task.sleep(nanoseconds: UInt64(rateLimitDelay * 1_000_000_000))
            }
        }

        logger.info("importing \(allTransactions.count) total transactions...")

        // Import using existing deduplication logic
        let result = try CSVImporter.importTransactions(allTransactions, into: context)
        try context.save()

        logger.info("sync complete: \(result.expensesImported) expenses, \(result.incomesImported) incomes imported, \(result.duplicatesSkipped) duplicates skipped, \(result.skipped) skipped")

        return result
    }

    /// Splits a date range into 31-day windows.
    private static func dateWindows(from: Date, to: Date) -> [(Date, Date)] {
        var windows: [(Date, Date)] = []
        var windowStart = from

        while windowStart < to {
            let windowEnd = min(windowStart.addingTimeInterval(maxWindowSeconds), to)
            windows.append((windowStart, windowEnd))
            windowStart = windowEnd
        }

        if windows.isEmpty {
            windows.append((from, to))
        }

        return windows
    }

    /// Converts a Monobank API statement into a CSVTransaction for import.
    private static func convertStatement(_ statement: MonobankStatement, accountCurrency: String) -> CSVTransaction? {
        // Skip held (pending) transactions
        guard !statement.hold else { return nil }

        let date = Date(timeIntervalSince1970: TimeInterval(statement.time))

        // Amounts are in minor units (kopecks) — divide by 100
        let cardAmount = Decimal(statement.amount) / 100
        let operationAmount = Decimal(statement.operationAmount) / 100
        let operationCurrency = MonobankAPIClient.currencyString(for: statement.currencyCode)

        let direction: String
        if statement.amount > 0 {
            direction = "IN"
        } else if statement.amount < 0 {
            direction = "OUT"
        } else {
            return nil // Skip zero-amount transactions
        }

        let amount: Decimal
        let baseCurrencyAmount: Decimal?
        let baseCurrency: String?

        if operationCurrency == accountCurrency {
            // Same currency — no conversion needed
            amount = abs(cardAmount)
            baseCurrencyAmount = nil
            baseCurrency = nil
        } else {
            // Foreign currency transaction
            amount = abs(operationAmount)
            baseCurrencyAmount = abs(cardAmount)
            baseCurrency = accountCurrency
        }

        let categoryName = MonobankCSVImporter.categoryName(forMCC: statement.mcc)

        let description = statement.comment ?? statement.description

        return CSVTransaction(
            direction: direction,
            status: "COMPLETED",
            date: date,
            amount: amount,
            currency: operationCurrency == accountCurrency ? accountCurrency : operationCurrency,
            categoryName: categoryName,
            targetName: description,
            destination: nil,
            baseCurrencyAmount: baseCurrencyAmount,
            baseCurrency: baseCurrency,
            externalId: "mono_\(statement.id)"
        )
    }
}
