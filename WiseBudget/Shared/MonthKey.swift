import Foundation

/// A `(year, month)` tuple used for grouping and comparing expense data
/// across months. Sortable via `sortValue` (year * 12 + month).
struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    enum ChartLabelStyle { case month, monthYear, yearAtJanuary }

    var shortLabel: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date.now
        return date.formatted(.dateTime.month(.abbreviated))
    }

    var fullLabel: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date.now
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    var yearLabel: String { String(year) }

    func chartLabel(_ style: ChartLabelStyle) -> String {
        switch style {
        case .month:         return shortLabel
        case .monthYear:     return fullLabel
        case .yearAtJanuary: return fullLabel
        }
    }

    var sortValue: Int { year * 12 + month }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.sortValue < rhs.sortValue
    }

    /// Returns `count` months ending at `anchor`, ordered oldest-first.
    static func recent(_ count: Int, endingAt anchor: MonthKey) -> [MonthKey] {
        let calendar = Calendar.current
        return (0..<count).reversed().compactMap { offset in
            let comps = DateComponents(year: anchor.year, month: anchor.month - offset)
            guard let date = calendar.date(from: comps),
                  let year = calendar.dateComponents([.year, .month], from: date).year,
                  let month = calendar.dateComponents([.year, .month], from: date).month
            else { return nil }
            return MonthKey(year: year, month: month)
        }
    }

    /// All twelve months of a calendar year, ordered oldest-first.
    static func allMonths(of year: Int) -> [MonthKey] {
        (1...12).map { MonthKey(year: year, month: $0) }
    }
}
