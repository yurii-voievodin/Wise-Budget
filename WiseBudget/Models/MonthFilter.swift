import Foundation

nonisolated enum TransactionSourceFilter: Hashable {
    case all
    case syncedOnly
    case manualOnly
}

nonisolated struct MonthFilter: Hashable {
    var year: Int
    var month: Int
    var foreignOnly: Bool = false
    var sourceFilter: TransactionSourceFilter = .all

    static func currentMonth() -> MonthFilter {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date.now)
        return MonthFilter(year: comps.year ?? 2025, month: comps.month ?? 1)
    }

    func moved(by delta: Int) -> MonthFilter {
        let comps = DateComponents(year: year, month: month + delta)
        let date = Calendar.current.date(from: comps) ?? Date.now
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        return MonthFilter(year: newComps.year ?? year, month: newComps.month ?? month)
    }

    func with(monthKey: MonthKey) -> MonthFilter {
        var copy = self
        copy.year = monthKey.year
        copy.month = monthKey.month
        return copy
    }

    var isFutureMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date.now)
        let currentYear = now.year ?? 0
        let currentMonth = now.month ?? 0
        return year > currentYear || (year == currentYear && month > currentMonth)
    }

    var startOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date.now
    }

    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date.now
    }
}

extension MonthFilter {
    private static let yearKey = "MonthFilter.year"
    private static let monthKey = "MonthFilter.month"

    /// Restores the user's last-viewed year/month, or falls back to the current month
    /// on first launch. `foreignOnly` and `sourceFilter` are intentionally not persisted — per-session toggles.
    static var stored: MonthFilter {
        let defaults = UserDefaults.standard
        guard
            let year = defaults.object(forKey: yearKey) as? Int,
            let month = defaults.object(forKey: monthKey) as? Int,
            (1...12).contains(month)
        else {
            return .currentMonth()
        }
        return MonthFilter(year: year, month: month)
    }

    func persist() {
        let defaults = UserDefaults.standard
        defaults.set(year, forKey: Self.yearKey)
        defaults.set(month, forKey: Self.monthKey)
    }
}
