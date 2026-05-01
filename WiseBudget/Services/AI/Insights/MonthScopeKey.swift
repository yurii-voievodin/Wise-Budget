import Foundation

/// Locale-independent month/year keys used to scope cached insights.
/// Keeping the format stable (`"YYYY-MM"`) guarantees cache lookups work
/// regardless of the user's display locale.
enum MonthScopeKey {
    static func make(year: Int, month: Int) -> String {
        let paddedMonth = month < 10 ? "0\(month)" : "\(month)"
        return "\(year)-\(paddedMonth)"
    }
}
