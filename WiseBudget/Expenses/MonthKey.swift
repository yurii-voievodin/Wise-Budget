import Foundation

/// A `(year, month)` tuple used for grouping and comparing expense data
/// across months. Sortable via `sortValue` (year * 12 + month).
struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    var shortLabel: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date.now
        return date.formatted(.dateTime.month(.abbreviated))
    }

    var fullLabel: String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date.now
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    func chartLabel(compact: Bool) -> String {
        compact ? shortLabel : fullLabel
    }

    var sortValue: Int { year * 12 + month }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        lhs.sortValue < rhs.sortValue
    }
}
