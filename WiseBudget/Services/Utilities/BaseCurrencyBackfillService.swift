import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "BaseCurrencyBackfill")

/// Fills in `baseCurrencyAmount` / `baseCurrency` for foreign-currency Expenses
/// and Incomes in a date range by fetching historical Wise rates. Groups by
/// (currency, day) so each unique pair is fetched at most once per run.
@MainActor
enum BaseCurrencyBackfillService {

    struct Result {
        var convertedCount: Int = 0
        var convertedExpenses: Int = 0
        var convertedIncomes: Int = 0
        var alreadyHadBase: Int = 0
        var sameCurrency: Int = 0
        var failedRateFetches: Int = 0
        var ratesFetched: Int = 0
        /// Keys: "<currency>->/<base>". Value: rate used.
        var perCurrencyConverted: [String: Int] = [:]
    }

    enum BackfillError: Error, LocalizedError {
        case missingWiseToken

        var errorDescription: String? {
            switch self {
            case .missingWiseToken:
                return "Wise API token is not configured. Connect Wise in Settings first."
            }
        }
    }

    /// Backfills expenses whose date falls in `dateRange` (half-open: start ≤ date < end).
    /// Returns a summary; throws only on configuration errors. Per-rate failures are
    /// counted in the result but do not abort the run.
    static func backfill(
        in dateRange: DateInterval,
        baseCurrency: String,
        context: ModelContext
    ) async throws -> Result {
        guard let token = KeychainHelper.loadToken(service: KeychainHelper.wiseService) else {
            throw BackfillError.missingWiseToken
        }

        let start = dateRange.start
        let end = dateRange.end
        let expenseDescriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.date >= start && expense.date < end
            }
        )
        let incomeDescriptor = FetchDescriptor<Income>(
            predicate: #Predicate<Income> { income in
                income.date >= start && income.date < end
            }
        )
        let expenses = try context.fetch(expenseDescriptor)
        let incomes = try context.fetch(incomeDescriptor)
        logger.info("Backfill scan: \(expenses.count) expenses, \(incomes.count) incomes in range, base=\(baseCurrency)")

        var result = Result()

        // Group eligible items by (kind, currency, day-key)
        let calendar = Calendar.current
        var expenseBuckets: [String: [Expense]] = [:]
        for expense in expenses {
            if expense.currency == baseCurrency {
                result.sameCurrency += 1
                continue
            }
            if expense.baseCurrencyAmount != nil {
                result.alreadyHadBase += 1
                continue
            }
            let day = calendar.startOfDay(for: expense.date)
            let key = "\(expense.currency)|\(Int(day.timeIntervalSince1970))"
            expenseBuckets[key, default: []].append(expense)
        }

        var incomeBuckets: [String: [Income]] = [:]
        for income in incomes {
            if income.currency == baseCurrency {
                result.sameCurrency += 1
                continue
            }
            if income.baseCurrencyAmount != nil {
                result.alreadyHadBase += 1
                continue
            }
            let day = calendar.startOfDay(for: income.date)
            let key = "\(income.currency)|\(Int(day.timeIntervalSince1970))"
            incomeBuckets[key, default: []].append(income)
        }

        let client = WiseAPIClient(token: token)

        // Cache rates by (currency, day) so expense + income on the same day share a fetch.
        var rateCache: [String: Decimal] = [:]
        var failedKeys: Set<String> = []

        func rate(for currency: String, on date: Date) async -> Decimal? {
            let day = calendar.startOfDay(for: date)
            let key = "\(currency)|\(Int(day.timeIntervalSince1970))"
            if let cached = rateCache[key] { return cached }
            if failedKeys.contains(key) { return nil }
            do {
                let wiseRate = try await client.fetchRate(source: currency, target: baseCurrency, time: date)
                let value = Decimal(wiseRate.rate)
                rateCache[key] = value
                result.ratesFetched += 1
                return value
            } catch {
                logger.error("Rate fetch failed for \(currency)->\(baseCurrency) on \(date): \(error.localizedDescription)")
                failedKeys.insert(key)
                return nil
            }
        }

        for (_, group) in expenseBuckets {
            guard let sample = group.first else { continue }
            if let rate = await rate(for: sample.currency, on: sample.date) {
                for expense in group {
                    expense.baseCurrencyAmount = round2(expense.amount * rate)
                    expense.baseCurrency = baseCurrency
                    result.convertedCount += 1
                    result.convertedExpenses += 1
                    result.perCurrencyConverted[sample.currency, default: 0] += 1
                }
            } else {
                result.failedRateFetches += group.count
            }
        }

        for (_, group) in incomeBuckets {
            guard let sample = group.first else { continue }
            if let rate = await rate(for: sample.currency, on: sample.date) {
                for income in group {
                    income.baseCurrencyAmount = round2(income.amount * rate)
                    income.baseCurrency = baseCurrency
                    result.convertedCount += 1
                    result.convertedIncomes += 1
                    result.perCurrencyConverted[sample.currency, default: 0] += 1
                }
            } else {
                result.failedRateFetches += group.count
            }
        }

        if result.convertedCount > 0 {
            try context.save()
        }

        logger.info("Backfill done: converted=\(result.convertedCount) (expenses=\(result.convertedExpenses), incomes=\(result.convertedIncomes)) failed=\(result.failedRateFetches) ratesFetched=\(result.ratesFetched)")
        return result
    }

    private static func round2(_ value: Decimal) -> Decimal {
        var result = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .plain)
        return rounded
    }
}
