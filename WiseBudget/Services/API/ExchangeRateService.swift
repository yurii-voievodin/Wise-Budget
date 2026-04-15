import Foundation
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "ExchangeRate")

@Observable
@MainActor
final class ExchangeRateService {
    private static let cacheTTL: TimeInterval = 24 * 60 * 60 // 24 hours

    private struct CacheEntry {
        let rate: Decimal
        let fetchedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]

    /// Returns the converted amount in the target currency, or nil if unavailable.
    func suggestedConversion(amount: Decimal, from source: String, to target: String, on date: Date) async -> Decimal? {
        guard source != target else { return nil }
        guard let token = KeychainHelper.loadToken(service: KeychainHelper.wiseService) else {
            logger.debug("No Wise token — skipping rate fetch")
            return nil
        }

        let cacheKey = "\(source)_\(target)_\(Self.dayString(from: date))"
        if let entry = cache[cacheKey], Date.now.timeIntervalSince(entry.fetchedAt) < Self.cacheTTL {
            return Self.rounded(amount * entry.rate)
        }

        do {
            let client = WiseAPIClient(token: token)
            let wiseRate = try await client.fetchRate(source: source, target: target, time: date)
            let rate = Decimal(wiseRate.rate)
            cache[cacheKey] = CacheEntry(rate: rate, fetchedAt: Date.now)
            logger.debug("Fetched rate \(source)->\(target): \(wiseRate.rate)")
            return Self.rounded(amount * rate)
        } catch {
            logger.error("Failed to fetch rate: \(error.localizedDescription)")
            return nil
        }
    }

    private static func rounded(_ value: Decimal) -> Decimal {
        var result = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 2, .plain)
        return rounded
    }

    private static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
