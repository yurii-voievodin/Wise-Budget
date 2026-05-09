import Foundation
import SwiftData
import OSLog

nonisolated private let logger = Logger(subsystem: "com.wisebudget", category: "WiseSync")

final class WiseSyncService {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Syncs Wise activities into the given model context for the specified date range.
    @MainActor
    static func sync(
        context: ModelContext,
        fromTimestamp: Double,
        toTimestamp: Double,
        onProgress: (@Sendable (SyncProgress) -> Void)? = nil
    ) async throws -> ImportResult {
        logger.info("sync started")
        onProgress?(SyncProgress(bank: "Wise", detail: "fetching activities", kind: .indeterminate))

        guard let token = KeychainHelper.loadToken(service: KeychainHelper.wiseService) else {
            logger.warning("sync aborted: no token in Keychain")
            throw WiseAPIError.noToken
        }

        let client = WiseAPIClient(token: token)

        // Fetch profiles and use the stored profile ID
        let profiles = try await client.fetchProfiles()

        let profileId = loadSelectedProfileId()
        let profile: WiseProfile
        if let pid = profileId, let found = profiles.first(where: { $0.id == pid }) {
            profile = found
        } else if let first = profiles.first {
            profile = first
        } else {
            throw WiseAPIError.noProfile
        }

        logger.debug("using profile \(profile.id, privacy: .private) (\(profile.fullName, privacy: .private))")

        let fromDate = Date(timeIntervalSince1970: fromTimestamp)
        let toDate = Date(timeIntervalSince1970: toTimestamp)
        logger.debug("sync from: \(dateFormatter.string(from: fromDate))")
        logger.debug("sync to: \(dateFormatter.string(from: toDate))")

        // Fetch all completed activities (handles pagination internally)
        let activities = try await client.fetchAllActivities(profileId: profile.id, since: fromDate, until: toDate)
        logger.info("fetched \(activities.count) activities")

        let allTransactions = activities.compactMap { activity -> CSVTransaction? in
            convertActivity(activity)
        }

        logger.info("importing \(allTransactions.count) transactions...")

        let result = try CSVImporter.importTransactions(allTransactions, into: context)
        try context.save()

        logger.info("sync complete: \(result.expensesImported) expenses, \(result.incomesImported) incomes imported, \(result.duplicatesSkipped) duplicates skipped, \(result.skipped) skipped")

        return result
    }

    /// Converts a Wise activity into a CSVTransaction for import.
    nonisolated static func convertActivity(_ activity: WiseActivity) -> CSVTransaction? {
        guard let amountString = activity.primaryAmount, !amountString.isEmpty else {
            logger.debug("skipping activity \(activity.id, privacy: .private): no primaryAmount")
            return nil
        }

        guard let (amount, currency) = parseFormattedAmount(amountString) else {
            logger.warning("skipping activity \(activity.id, privacy: .private): could not parse amount '\(amountString, privacy: .private)'")
            return nil
        }

        guard let dateString = activity.createdOn, let date = parseDate(dateString) else {
            logger.warning("skipping activity \(activity.id, privacy: .private): could not parse date")
            return nil
        }

        // Inter-balance moves (e.g. between EUR and savings jars) stay in history but
        // are flagged so statistics exclude them. Other Wise transfer types lack
        // recipient info in the API and are left unflagged for users to mark manually.
        let isInternalTransfer = activity.type == "INTERBALANCE"

        // Determine direction: the Wise API wraps incoming amounts in <positive> tags
        // (e.g. "<positive>+ 3,754.76 EUR</positive>") and outgoing amounts are plain
        // (e.g. "18.55 EUR"). Check for this tag first — it's the most reliable signal.
        let isExplicitlyPositive = amountString.contains("<positive>")

        let expenseTypes: Set<String> = [
            "CARD_PAYMENT", "CARD_TRANSACTION",
            "DIRECT_DEBIT_TRANSACTION", "DIRECT_DEBIT_INSTRUCTION",
            "TRANSFER", "SEND_ORDER", "SEND_ORDER_EXECUTION", "BATCH_TRANSFER",
        ]

        let direction: String
        if amount == 0 {
            return nil // Skip zero-amount
        } else if isExplicitlyPositive || amount < 0 {
            // Negative parsed amount means the raw string had a minus sign → income
            // <positive> tag means Wise explicitly marked it as incoming
            direction = amount < 0 ? "OUT" : "IN"
        } else if expenseTypes.contains(activity.type) {
            direction = "OUT"
        } else {
            direction = "IN"
        }

        let absAmount = abs(amount)
        let description = stripHTML(activity.title ?? activity.description ?? "Wise Activity")

        let categoryName: String
        if direction == "OUT" {
            if activity.type == "CARD_TRANSACTION" || activity.type == "CARD_PAYMENT",
               let merchantCategory = MerchantCategoryMapping.category(for: description) {
                categoryName = merchantCategory
            } else {
                categoryName = categoryForActivityType(activity.type)
            }
        } else {
            categoryName = DefaultIncomeCategory.other.rawValue
        }

        // Parse secondary amount for currency conversion info
        let baseCurrencyAmount: Decimal?
        let baseCurrency: String?
        if let secondaryString = activity.secondaryAmount,
           let (secAmount, secCurrency) = parseFormattedAmount(secondaryString),
           secCurrency != currency {
            baseCurrencyAmount = abs(secAmount)
            baseCurrency = secCurrency
        } else {
            baseCurrencyAmount = nil
            baseCurrency = nil
        }

        return CSVTransaction(
            direction: direction,
            status: "COMPLETED",
            date: date,
            amount: absAmount,
            currency: currency,
            categoryName: categoryName,
            targetName: description,
            destination: nil,
            baseCurrencyAmount: baseCurrencyAmount,
            baseCurrency: baseCurrency,
            externalId: "\(TransactionSource.wisePrefix)\(activity.id)",
            isInternalTransfer: isInternalTransfer
        )
    }

    /// Parses a formatted amount string like "10.00 EUR", "-25.50 GBP", "1,234.56 USD",
    /// or "<positive>+ 3,754.76 EUR</positive>". Tolerates either dot- or
    /// comma-decimal styles ("19.07 EUR" and "19,07 EUR" both yield 19.07) so
    /// the parser is not at the mercy of the device's `Accept-Language`.
    /// Returns (amount as Decimal, currency code) or nil if parsing fails.
    nonisolated static func parseFormattedAmount(_ formatted: String) -> (Decimal, String)? {
        let stripped = stripHTML(formatted).trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return nil }

        let parts = stripped.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }

        let currencyCode = parts.last!
        guard currencyCode.count == 3, currencyCode == currencyCode.uppercased() else { return nil }

        let raw = parts.dropLast().joined()
            .replacingOccurrences(of: "+", with: "")
        guard !raw.isEmpty else { return nil }

        let normalized = normalizeDecimalString(raw)
        guard let amount = Decimal(string: normalized) else { return nil }

        return (amount, currencyCode)
    }

    /// Resolves an ambiguous numeric string into a POSIX-style decimal that
    /// `Decimal(string:)` can parse. Handles four shapes:
    ///   "1,234.56"  → "1234.56"   (both seps, dot last → dot is decimal)
    ///   "1.234,56"  → "1234.56"   (both seps, comma last → comma is decimal)
    ///   "19,07"     → "19.07"     (lone comma with 1–2 trailing digits → decimal)
    ///   "1,234"     → "1234"      (lone comma with 3 trailing digits → thousand sep)
    nonisolated private static func normalizeDecimalString(_ raw: String) -> String {
        let dot = scan(raw, for: ".")
        let comma = scan(raw, for: ",")

        switch (dot.count, comma.count) {
        case (0, 0):
            return raw
        case (_, 0):
            return dot.count == 1 && (1...2).contains(dot.trailing)
                ? raw
                : raw.replacingOccurrences(of: ".", with: "")
        case (0, _):
            return comma.count == 1 && (1...2).contains(comma.trailing)
                ? raw.replacingOccurrences(of: ",", with: ".")
                : raw.replacingOccurrences(of: ",", with: "")
        default:
            if dot.lastOffset > comma.lastOffset {
                return raw.replacingOccurrences(of: ",", with: "")
            } else {
                var swapped = raw
                swapped.removeAll(where: { $0 == "." })
                return swapped.replacingOccurrences(of: ",", with: ".")
            }
        }
    }

    /// Single-pass tally of a separator: total occurrences, offset of the last
    /// occurrence, and how many characters follow it.
    nonisolated private static func scan(_ s: String, for separator: Character) -> (count: Int, lastOffset: Int, trailing: Int) {
        var count = 0
        var lastOffset = -1
        for (i, c) in s.enumerated() where c == separator {
            count += 1
            lastOffset = i
        }
        let trailing = lastOffset < 0 ? 0 : s.count - lastOffset - 1
        return (count, lastOffset, trailing)
    }

    nonisolated private static func parseDate(_ dateString: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        // Try "yyyy-MM-dd HH:mm:ss" format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: dateString)
    }

    /// Strips HTML tags from a string (e.g. "<strong>Glovo</strong>" → "Glovo").
    nonisolated private static func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Maps Wise activity type to app category (fallback when merchant name matching fails).
    nonisolated static func categoryForActivityType(_ type: String) -> String {
        switch type {
        case "CARD_TRANSACTION", "CARD_PAYMENT":
            return DefaultExpenseCategory.shopping.rawValue
        case "DIRECT_DEBIT_TRANSACTION", "DIRECT_DEBIT_INSTRUCTION":
            return DefaultExpenseCategory.subscription.rawValue
        case "TRANSFER", "SEND_ORDER", "SEND_ORDER_EXECUTION", "BATCH_TRANSFER":
            return DefaultExpenseCategory.other.rawValue
        case "BALANCE_TRANSACTION":
            return DefaultExpenseCategory.other.rawValue
        case "CARD_CASHBACK", "BALANCE_CASHBACK", "REWARD", "REWARDS_REDEMPTION":
            return DefaultExpenseCategory.other.rawValue
        case "FEE_REFUND", "INCIDENT_REFUND":
            return DefaultExpenseCategory.other.rawValue
        default:
            return DefaultExpenseCategory.other.rawValue
        }
    }

    // MARK: - UserDefaults Helpers

    static func loadSelectedProfileId() -> Int? {
        let value = UserDefaults.standard.integer(forKey: "wiseSelectedProfileId")
        return value > 0 ? value : nil
    }

    static func saveSelectedProfileId(_ id: Int) {
        UserDefaults.standard.set(id, forKey: "wiseSelectedProfileId")
    }
}
