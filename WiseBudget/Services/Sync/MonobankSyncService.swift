import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankSync")

final class MonobankSyncService {

    /// Maximum date range per Monobank statement request (31 days).
    private static let maxWindowSeconds: TimeInterval = 31 * 24 * 60 * 60

    /// Delay between consecutive API calls to respect rate limits.
    private static let rateLimitDelay: TimeInterval = 2.0

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Syncs Monobank transactions into the given model context for the specified date range.
    static func sync(context: ModelContext, fromTimestamp: Double, toTimestamp: Double) async throws -> ImportResult {
        logger.info("sync started")

        guard let token = KeychainHelper.loadToken(service: KeychainHelper.monobankService) else {
            logger.warning("sync aborted: no token in Keychain")
            throw MonobankAPIError.noToken
        }

        let client = MonobankAPIClient(token: token)
        let selectedIds = MonobankConnectSheet.loadSelectedAccountIds()

        // Use cached account details to avoid an extra API call
        let allCachedAccounts: [(id: String, currencyCode: Int, iban: String?)]
        let accountsToSync: [(id: String, currencyCode: Int, iban: String?)]
        if let cached = MonobankConnectSheet.loadAccountDetails() {
            allCachedAccounts = cached
            if selectedIds.isEmpty {
                accountsToSync = cached
                logger.info("using cached accounts, syncing all \(cached.count)")
            } else {
                accountsToSync = cached.filter { selectedIds.contains($0.id) }
                logger.info("using cached accounts, syncing \(accountsToSync.count) of \(cached.count) (filtered)")
            }
        } else {
            // Fallback: fetch from API if no cache (e.g. first sync after app update)
            logger.debug("no cached accounts, fetching client info...")
            let clientInfo = try await client.fetchClientInfo()
            MonobankConnectSheet.saveAccountDetails(clientInfo.accounts)
            let all = clientInfo.accounts.map { (id: $0.id, currencyCode: $0.currencyCode, iban: $0.iban) }
            allCachedAccounts = all
            if selectedIds.isEmpty {
                accountsToSync = all
            } else {
                accountsToSync = all.filter { selectedIds.contains($0.id) }
            }
            logger.info("fetched and cached \(clientInfo.accounts.count) accounts, syncing \(accountsToSync.count)")
        }

        // Collect all user IBANs to detect own-account transfers
        let ownIbans = Set(allCachedAccounts.compactMap { $0.iban })

        let defaultCurrency = UserDefaults.standard.string(forKey: "defaultCurrency")
            ?? Locale.current.currency?.identifier ?? "USD"

        let fromDate = Date(timeIntervalSince1970: fromTimestamp)
        let toDate = Date(timeIntervalSince1970: toTimestamp)
        logger.debug("sync from: \(dateFormatter.string(from: fromDate))")
        logger.debug("sync to: \(dateFormatter.string(from: toDate))")

        var allTransactions: [CSVTransaction] = []
        var requestCount = 0

        // Count total requests to know when we're on the last one
        let windowsPerAccount = dateWindows(from: fromDate, to: toDate).count
        let totalRequests = accountsToSync.count * windowsPerAccount

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
                    convertStatement(statement, accountCurrency: currency, ownIbans: ownIbans, defaultCurrency: defaultCurrency)
                }
                allTransactions.append(contentsOf: transactions)
                logger.debug("fetched \(statements.count) statements, \(transactions.count) converted")

                requestCount += 1
                // Respect rate limits between consecutive API calls
                if requestCount < totalRequests {
                    logger.debug("rate limit delay (\(rateLimitDelay)s)...")
                    try await Task.sleep(nanoseconds: UInt64(rateLimitDelay * 1_000_000_000))
                }
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
    static func convertStatement(_ statement: MonobankStatement, accountCurrency: String, ownIbans: Set<String>, defaultCurrency: String) -> CSVTransaction? {
        // TODO: Monobank marks recent transactions as hold=true for days before settling.
        // Previously we skipped them, but that caused all recent transactions to be missing.
        // If duplicate imports become an issue, re-enable: guard !statement.hold else { return nil }

        // Skip own-account transfers
        if let counterIban = statement.counterIban, ownIbans.contains(counterIban) {
            logger.debug("skipping own-account transfer (IBAN match): \(statement.id)")
            return nil
        }

        // Skip FOP ↔ personal account transfers (incoming side has no counterIban)
        let desc = statement.description.lowercased()
        if desc.contains("рахунку фоп") || desc.contains("рахунок фоп") {
            logger.debug("skipping FOP transfer: \(statement.id)")
            return nil
        }

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
            // Foreign currency transaction — store the merchant amount in its original currency.
            amount = abs(operationAmount)
            if accountCurrency == defaultCurrency {
                // Account currency matches the user's default currency (e.g. UAH account + UAH default),
                // so the bank's converted amount is useful — store it as baseCurrencyAmount.
                baseCurrencyAmount = abs(cardAmount)
                baseCurrency = accountCurrency
            } else {
                // Account currency differs from the user's default currency (e.g. UAH account + USD default),
                // so the bank's UAH amount is not useful. Skip it and let the app convert on display.
                baseCurrencyAmount = nil
                baseCurrency = nil
            }
        }

        let categoryName = MCCCategoryMapping.categoryName(forMCC: statement.mcc)

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
