import Foundation
import SwiftData
import OSLog

nonisolated private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankSync")

final class MonobankSyncService {
    typealias SyncAccount = (id: String, currencyCode: Int, iban: String?)
    typealias FetchStatements = @Sendable (_ accountId: String, _ from: Date, _ to: Date) async throws -> [MonobankStatement]
    typealias Sleep = @Sendable (_ duration: TimeInterval) async throws -> Void

    /// Maximum date range per Monobank statement request (31 days).
    nonisolated private static let maxWindowSeconds: TimeInterval = 31 * 24 * 60 * 60

    /// Delay between consecutive API calls to respect rate limits.
    private static let rateLimitDelay: TimeInterval = 3.0

    /// Extra backoff delays after Monobank responds with HTTP 429.
    private static let rateLimitRetryDelays: [TimeInterval] = [5.0, 10.0, 20.0]

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
        let allCachedAccounts: [SyncAccount]
        let accountsToSync: [SyncAccount]
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
        return try await sync(
            context: context,
            from: fromDate,
            to: toDate,
            accountsToSync: accountsToSync,
            ownIbans: ownIbans,
            defaultCurrency: defaultCurrency,
            fetchStatements: { accountId, from, to in
                try await fetchStatementsWithRetry(
                    fetchStatements: { accountId, from, to in
                        try await client.fetchStatements(accountId: accountId, from: from, to: to)
                    },
                    accountId: accountId,
                    from: from,
                    to: to,
                    sleep: defaultSleep
                )
            },
            sleep: defaultSleep
        )
    }

    static func sync(
        context: ModelContext,
        from: Date,
        to: Date,
        accountsToSync: [SyncAccount],
        ownIbans: Set<String>,
        defaultCurrency: String,
        fetchStatements: FetchStatements,
        sleep: Sleep
    ) async throws -> ImportResult {
        logger.debug("sync from: \(dateFormatter.string(from: from))")
        logger.debug("sync to: \(dateFormatter.string(from: to))")

        var totalResult = ImportResult()
        var requestCount = 0

        let windows = dateWindows(from: from, to: to)
        let totalRequests = accountsToSync.count * windows.count

        for account in accountsToSync {
            try Task.checkCancellation()
            let currency = MonobankAPIClient.currencyString(for: account.currencyCode)
            logger.debug("processing account \(account.id, privacy: .private) (\(currency))")
            logger.debug("date range split into \(windows.count) window(s)")

            for (windowStart, windowEnd) in windows {
                try Task.checkCancellation()
                logger.debug("fetching statements: \(dateFormatter.string(from: windowStart)) -> \(dateFormatter.string(from: windowEnd))")

                let statements = try await fetchStatements(account.id, windowStart, windowEnd)
                let transactions = statements.compactMap { statement -> CSVTransaction? in
                    convertStatement(statement, accountCurrency: currency, ownIbans: ownIbans, defaultCurrency: defaultCurrency)
                }
                logger.debug("fetched \(statements.count) statements, \(transactions.count) converted")

                let importResult = try CSVImporter.importTransactions(transactions, into: context)
                try context.save()
                merge(importResult, into: &totalResult)

                requestCount += 1
                if requestCount < totalRequests {
                    logger.debug("rate limit delay (\(rateLimitDelay)s)...")
                    try await sleep(rateLimitDelay)
                }
            }
        }

        logger.info("sync complete: \(totalResult.expensesImported) expenses, \(totalResult.incomesImported) incomes imported, \(totalResult.duplicatesSkipped) duplicates skipped, \(totalResult.skipped) skipped")

        return totalResult
    }

    /// Splits a date range into 31-day windows, newest first.
    nonisolated static func dateWindows(from: Date, to: Date) -> [(Date, Date)] {
        var windows: [(Date, Date)] = []
        var windowEnd = to

        while windowEnd > from {
            let windowStart = max(windowEnd.addingTimeInterval(-maxWindowSeconds), from)
            windows.append((windowStart, windowEnd))
            windowEnd = windowStart
        }

        if windows.isEmpty {
            windows.append((from, to))
        }

        return windows
    }

    static func fetchStatementsWithRetry(
        fetchStatements: FetchStatements,
        accountId: String,
        from: Date,
        to: Date,
        sleep: Sleep
    ) async throws -> [MonobankStatement] {
        var attempt = 0

        while true {
            do {
                return try await fetchStatements(accountId, from, to)
            } catch MonobankAPIError.rateLimited {
                guard attempt < rateLimitRetryDelays.count else {
                    throw MonobankAPIError.rateLimited
                }

                let delay = rateLimitRetryDelays[attempt]
                attempt += 1
                logger.warning("Monobank rate limited account \(accountId, privacy: .private). Retrying in \(delay)s (attempt \(attempt) of \(rateLimitRetryDelays.count))")
                try await sleep(delay)
            }
        }
    }

    private static func merge(_ partial: ImportResult, into total: inout ImportResult) {
        total.expensesImported += partial.expensesImported
        total.incomesImported += partial.incomesImported
        total.skipped += partial.skipped
        total.duplicatesSkipped += partial.duplicatesSkipped
    }

    private static func defaultSleep(_ duration: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(duration))
    }

    /// Converts a Monobank API statement into a CSVTransaction for import.
    nonisolated static func convertStatement(_ statement: MonobankStatement, accountCurrency: String, ownIbans: Set<String>, defaultCurrency: String) -> CSVTransaction? {
        // TODO: Monobank marks recent transactions as hold=true for days before settling.
        // Previously we skipped them, but that caused all recent transactions to be missing.
        // If duplicate imports become an issue, re-enable: guard !statement.hold else { return nil }

        // Skip own-account transfers
        if let counterIban = statement.counterIban, ownIbans.contains(counterIban) {
            logger.debug("skipping own-account transfer (IBAN match): \(statement.id, privacy: .private)")
            return nil
        }

        // Skip FOP ↔ personal account transfers (incoming side has no counterIban)
        let desc = statement.description.lowercased()
        if desc.contains("рахунку фоп") || desc.contains("рахунок фоп") {
            logger.debug("skipping FOP transfer: \(statement.id, privacy: .private)")
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
