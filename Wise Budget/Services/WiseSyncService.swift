import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "WiseSync")

final class WiseSyncService {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    /// Syncs Wise activities into the given model context.
    /// Fetches all completed activities from the last sync date (or start of current month) until now.
    static func sync(context: ModelContext, lastSyncTimestamp: Double?) async throws -> ImportResult {
        logger.info("sync started")

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

        logger.debug("using profile \(profile.id) (\(profile.fullName, privacy: .private))")

        // Determine the start date
        let fromDate: Date
        if let lastSync = lastSyncTimestamp, lastSync > 0 {
            fromDate = Date(timeIntervalSince1970: lastSync)
            logger.debug("sync from last sync: \(dateFormatter.string(from: fromDate))")
        } else {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: Date())
            fromDate = calendar.date(from: components) ?? Date()
            logger.debug("sync from start of month: \(dateFormatter.string(from: fromDate))")
        }
        let toDate = Date()
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
    private static func convertActivity(_ activity: WiseActivity) -> CSVTransaction? {
        guard let amountString = activity.primaryAmount, !amountString.isEmpty else {
            logger.debug("skipping activity \(activity.id): no primaryAmount")
            return nil
        }

        guard let (amount, currency) = parseFormattedAmount(amountString) else {
            logger.warning("skipping activity \(activity.id): could not parse amount '\(amountString)'")
            return nil
        }

        guard let dateString = activity.createdOn, let date = parseDate(dateString) else {
            logger.warning("skipping activity \(activity.id): could not parse date")
            return nil
        }

        // Determine direction based on activity type and amount sign.
        // The Wise API returns positive amounts for outgoing payments (e.g. "18.55 EUR" for a card payment),
        // so we cannot rely on the sign alone. Use the activity type to identify expenses.
        let expenseTypes: Set<String> = [
            "CARD_PAYMENT", "CARD_TRANSACTION",
            "DIRECT_DEBIT_TRANSACTION", "DIRECT_DEBIT_INSTRUCTION",
            "TRANSFER", "SEND_ORDER", "SEND_ORDER_EXECUTION", "BATCH_TRANSFER",
        ]

        let direction: String
        if amount == 0 {
            return nil // Skip zero-amount
        } else if amount < 0 || expenseTypes.contains(activity.type) {
            direction = "OUT"
        } else {
            direction = "IN"
        }

        let absAmount = abs(amount)
        let categoryName = categoryForActivityType(activity.type)
        let description = stripHTML(activity.title ?? activity.description ?? "Wise Activity")

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
            baseCurrency: baseCurrency
        )
    }

    /// Parses a formatted amount string like "10.00 EUR", "-25.50 GBP", or "1,234.56 USD".
    /// Returns (amount as Decimal, currency code) or nil if parsing fails.
    static func parseFormattedAmount(_ formatted: String) -> (Decimal, String)? {
        let trimmed = formatted.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Split into components — the currency code is typically the last 3-letter word
        let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }

        let currencyCode = parts.last!
        // Currency codes are 3 uppercase letters
        guard currencyCode.count == 3, currencyCode == currencyCode.uppercased() else { return nil }

        // Everything before the currency is the number (may contain commas, minus sign, etc.)
        let numberParts = parts.dropLast()
        let numberString = numberParts.joined()
            .replacingOccurrences(of: ",", with: "") // Remove thousand separators

        guard let amount = Decimal(string: numberString) else { return nil }

        return (amount, currencyCode)
    }

    private static func parseDate(_ dateString: String) -> Date? {
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
    private static func stripHTML(_ string: String) -> String {
        string.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    /// Maps Wise activity type to app category.
    static func categoryForActivityType(_ type: String) -> String {
        switch type {
        case "CARD_TRANSACTION", "CARD_PAYMENT":
            return "Shopping"
        case "DIRECT_DEBIT_TRANSACTION", "DIRECT_DEBIT_INSTRUCTION":
            return "Utilities"
        case "TRANSFER", "SEND_ORDER", "SEND_ORDER_EXECUTION", "BATCH_TRANSFER":
            return "Other"
        case "BALANCE_TRANSACTION":
            return "Other"
        case "CARD_CASHBACK", "BALANCE_CASHBACK", "REWARD", "REWARDS_REDEMPTION":
            return "Other"
        case "FEE_REFUND", "INCIDENT_REFUND":
            return "Other"
        default:
            return "Other"
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
