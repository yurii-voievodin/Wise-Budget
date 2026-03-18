import Foundation

struct ExpenseFilter: Hashable {
    var year: Int
    var month: Int
    var foreignOnly: Bool = false
    var planCurrency: String? = nil

    static func currentMonth() -> ExpenseFilter {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return ExpenseFilter(year: comps.year ?? 2025, month: comps.month ?? 1)
    }

    func moved(by delta: Int) -> ExpenseFilter {
        let comps = DateComponents(year: year, month: month + delta)
        let date = Calendar.current.date(from: comps) ?? Date()
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        return ExpenseFilter(year: newComps.year ?? year, month: newComps.month ?? month)
    }

    var startOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth) ?? Date()
    }
}
