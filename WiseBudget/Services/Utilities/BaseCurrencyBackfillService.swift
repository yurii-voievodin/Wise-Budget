import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "BaseCurrencyBackfill")

/// Fills in `baseCurrencyAmount` / `baseCurrency` for foreign-currency Expenses
/// in a date range by fetching historical Wise rates. Groups by (currency, day)
/// so each unique pair is fetched at most once per run.
@MainActor
enum BaseCurrencyBackfillService {

    struct Result {
        var convertedCount: Int = 0
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
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.date >= start && expense.date < end
            }
        )
        let expenses = try context.fetch(descriptor)
        logger.info("Backfill scan: \(expenses.count) expenses in range, base=\(baseCurrency)")

        var result = Result()

        // Group eligible expenses by (currency, day-key)
        let calendar = Calendar.current
        var buckets: [String: [Expense]] = [:]
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
            buckets[key, default: []].append(expense)
        }

        let client = WiseAPIClient(token: token)

        for (_, group) in buckets {
            guard let sample = group.first else { continue }
            let date = sample.date
            let currency = sample.currency
            do {
                let wiseRate = try await client.fetchRate(source: currency, target: baseCurrency, time: date)
                let rate = Decimal(wiseRate.rate)
                result.ratesFetched += 1
                for expense in group {
                    let converted = round2(expense.amount * rate)
                    expense.baseCurrencyAmount = converted
                    expense.baseCurrency = baseCurrency
                    result.convertedCount += 1
                    result.perCurrencyConverted[currency, default: 0] += 1
                }
            } catch {
                logger.error("Rate fetch failed for \(currency)->\(baseCurrency) on \(date): \(error.localizedDescription)")
                result.failedRateFetches += group.count
            }
        }

        if result.convertedCount > 0 {
            try context.save()
        }

        logger.info("Backfill done: converted=\(result.convertedCount) failed=\(result.failedRateFetches) ratesFetched=\(result.ratesFetched)")
        return result
    }

    private static func round2(_ value: Decimal) -> Decimal {
        var result = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .plain)
        return rounded
    }
}
