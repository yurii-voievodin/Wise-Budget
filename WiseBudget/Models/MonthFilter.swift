import Foundation

nonisolated struct MonthFilter: Hashable {
    var year: Int
    var month: Int
    var foreignOnly: Bool = false

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
