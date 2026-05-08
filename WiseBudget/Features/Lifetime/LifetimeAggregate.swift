import Foundation

/// One pass over the full ledger that powers every section of `LifetimeView`.
/// All amounts are pre-converted to the user's default currency.
struct LifetimeAggregate {
    struct YearTotals: Identifiable {
        let year: Int
        let income: Double
        let expenses: Double

        var id: Int { year }
        var net: Double { income - expenses }
        var savingsRate: Double? { income > 0 ? net / income : nil }
    }

    struct CumulativePoint: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    let totalIncome: Double
    let totalExpenses: Double
    let firstDate: Date?
    let lastDate: Date?
    let yearRows: [YearTotals]
    let cumulativeNet: [CumulativePoint]
    let expenseCategories: [CategoryChartSlice]
    let incomeCategories: [CategoryChartSlice]

    var net: Double { totalIncome - totalExpenses }
    var hasData: Bool { !yearRows.isEmpty }

    static func make(expenses: [Expense], incomes: [Income], currency: String) -> Self {
        let calendar = Calendar.current

        var yearIncome: [Int: Double] = [:]
        var yearExpense: [Int: Double] = [:]
        var monthIncome: [MonthKey: Double] = [:]
        var monthExpense: [MonthKey: Double] = [:]
        var expenseByCat: [String: Double] = [:]
        var incomeByCat: [String: Double] = [:]
        var firstDate: Date?
        var lastDate: Date?

        func amount<T: CurrencyConvertible>(_ item: T) -> Double {
            NSDecimalNumber(decimal: item.convertedAmount(to: currency) ?? .zero).doubleValue
        }

        for income in incomes {
            let value = amount(income)
            let c = calendar.dateComponents([.year, .month], from: income.date)
            guard let y = c.year, let m = c.month else { continue }
            yearIncome[y, default: 0] += value
            monthIncome[MonthKey(year: y, month: m), default: 0] += value
            let cat = income.category?.name ?? "Uncategorized"
            incomeByCat[cat, default: 0] += value
            firstDate = min(firstDate ?? income.date, income.date)
            lastDate = max(lastDate ?? income.date, income.date)
        }

        for expense in expenses {
            let value = amount(expense)
            let c = calendar.dateComponents([.year, .month], from: expense.date)
            guard let y = c.year, let m = c.month else { continue }
            yearExpense[y, default: 0] += value
            monthExpense[MonthKey(year: y, month: m), default: 0] += value
            let cat = expense.category?.name ?? "Uncategorized"
            expenseByCat[cat, default: 0] += value
            firstDate = min(firstDate ?? expense.date, expense.date)
            lastDate = max(lastDate ?? expense.date, expense.date)
        }

        let years = Set(yearIncome.keys).union(yearExpense.keys).sorted()
        let yearRows = years.map { year in
            YearTotals(
                year: year,
                income: yearIncome[year, default: 0],
                expenses: yearExpense[year, default: 0]
            )
        }

        let allMonths = Set(monthIncome.keys).union(monthExpense.keys).sorted()
        var running: Double = 0
        let cumulative: [CumulativePoint] = allMonths.map { key in
            running += monthIncome[key, default: 0] - monthExpense[key, default: 0]
            let date = calendar.date(from: DateComponents(year: key.year, month: key.month, day: 1)) ?? Date()
            return CumulativePoint(date: date, value: running)
        }

        let expenseSlices = expenseByCat.map { name, total in
            CategoryChartSlice(
                name: name,
                iconName: DefaultExpenseCategory(rawValue: name)?.iconName ?? "ellipsis.circle",
                total: total
            )
        }
        let incomeSlices = incomeByCat.map { name, total in
            CategoryChartSlice(
                name: name,
                iconName: DefaultIncomeCategory(rawValue: name)?.iconName ?? "ellipsis.circle",
                total: total
            )
        }

        return Self(
            totalIncome: yearIncome.values.reduce(0, +),
            totalExpenses: yearExpense.values.reduce(0, +),
            firstDate: firstDate,
            lastDate: lastDate,
            yearRows: yearRows,
            cumulativeNet: cumulative,
            expenseCategories: expenseSlices,
            incomeCategories: incomeSlices
        )
    }
}

extension LifetimeAggregate {
    /// e.g. "10 yrs 4 mo".
    static func formatSpan(from start: Date?, to end: Date?) -> String {
        guard let start, let end, end >= start else { return "—" }
        let comps = Calendar.current.dateComponents([.year, .month], from: start, to: end)
        let years = comps.year ?? 0
        let months = comps.month ?? 0
        if years == 0 && months == 0 { return "<1 mo" }
        if years == 0 { return "\(months) mo" }
        if months == 0 { return "\(years) yr\(years == 1 ? "" : "s")" }
        return "\(years) yr\(years == 1 ? "" : "s") \(months) mo"
    }
}
