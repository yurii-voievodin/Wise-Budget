import Foundation

struct CashflowAggregate {
    let months: [MonthlyTotals]
    let periodLabel: String

    static let empty = CashflowAggregate(months: [], periodLabel: "")

    var totalIncome: Decimal { months.reduce(.zero) { $0 + $1.income } }
    var totalExpenses: Decimal { months.reduce(.zero) { $0 + $1.expenses } }
    var balance: Decimal { totalIncome - totalExpenses }

    static func make(
        timeRange: CashflowTimeRange,
        filter: MonthFilter,
        expenses: [Expense],
        incomes: [Income],
        currency: String
    ) -> CashflowAggregate {
        let calendar = Calendar.current
        var incomeByMonth: [MonthKey: Decimal] = [:]
        var expensesByMonth: [MonthKey: Decimal] = [:]

        for item in incomes {
            guard let key = monthKey(for: item.date, calendar: calendar) else { continue }
            incomeByMonth[key, default: 0] += item.convertedAmount(to: currency) ?? .zero
        }
        for item in expenses {
            guard let key = monthKey(for: item.date, calendar: calendar) else { continue }
            expensesByMonth[key, default: 0] += item.convertedAmount(to: currency) ?? .zero
        }

        let range = monthRange(
            timeRange: timeRange,
            filter: filter,
            knownMonths: Set(incomeByMonth.keys).union(expensesByMonth.keys)
        )

        let totals = range.reversed().map { key in
            MonthlyTotals(
                month: key,
                income: incomeByMonth[key] ?? 0,
                expenses: expensesByMonth[key] ?? 0
            )
        }
        .filter(\.hasActivity)

        return CashflowAggregate(months: totals, periodLabel: label(for: range))
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> MonthKey? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }
        return MonthKey(year: year, month: month)
    }

    private static func monthRange(
        timeRange: CashflowTimeRange,
        filter: MonthFilter,
        knownMonths: Set<MonthKey>
    ) -> [MonthKey] {
        let anchor = MonthKey(year: filter.year, month: filter.month)
        switch timeRange {
        case .sixMonths: return MonthKey.recent(6, endingAt: anchor)
        case .year: return MonthKey.recent(12, endingAt: anchor)
        case .lifetime: return knownMonths.sorted()
        }
    }

    private static func label(for range: [MonthKey]) -> String {
        guard let first = range.first, let last = range.last else { return "" }
        if first == last { return first.fullLabel }
        return "\(first.fullLabel) — \(last.fullLabel)"
    }
}
