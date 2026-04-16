import Foundation

/// Compact, LLM-friendly snapshot of one month of spending.
/// Built on the Dashboard and serialized to JSON for the Foundation Models prompt.
/// Kept deliberately small (< 2 KB) — only aggregates, no per-transaction data.
struct SpendingSummary: Codable, Sendable {
    struct CategoryTotal: Codable, Sendable {
        let name: String
        let amount: Double
        let percentOfExpenses: Double
    }

    let month: String           // e.g. "March 2026"
    let currency: String        // e.g. "EUR"
    let totalIncome: Double
    let totalExpenses: Double
    let balance: Double
    let transactionCount: Int
    let topCategories: [CategoryTotal]

    func encodedAsJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    var isEmpty: Bool {
        transactionCount == 0
    }
}

extension SpendingSummary {
    /// Builds a summary from raw expenses and incomes (grouping happens here).
    /// Used by unit tests and callers that don't already have category slices.
    static func build(
        monthFilter: MonthFilter,
        currency: String,
        expenses: [Expense],
        incomes: [Income],
        topCategoryLimit: Int = 8
    ) -> SpendingSummary {
        let totalIncome = incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }
        let totalExpenses = expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }

        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        let slices: [CategoryChartSlice] = grouped.compactMap { name, items in
            let sum = items.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: currency) ?? .zero) }
            guard sum > .zero else { return nil }
            return CategoryChartSlice(name: name, iconName: "", total: NSDecimalNumber(decimal: sum).doubleValue)
        }

        return build(
            monthFilter: monthFilter,
            currency: currency,
            totalIncome: NSDecimalNumber(decimal: totalIncome).doubleValue,
            totalExpenses: NSDecimalNumber(decimal: totalExpenses).doubleValue,
            transactionCount: expenses.count + incomes.count,
            expenseSlices: slices,
            topCategoryLimit: topCategoryLimit
        )
    }

    /// Builds a summary from already-computed totals and category slices.
    /// Preferred when the caller (e.g. the Dashboard) has already grouped the data for charts.
    static func build(
        monthFilter: MonthFilter,
        currency: String,
        totalIncome: Double,
        totalExpenses: Double,
        transactionCount: Int,
        expenseSlices: [CategoryChartSlice],
        topCategoryLimit: Int = 8
    ) -> SpendingSummary {
        let categoryTotals: [CategoryTotal] = expenseSlices
            .sorted { $0.total > $1.total }
            .prefix(topCategoryLimit)
            .map { slice in
                let pct = totalExpenses > 0 ? slice.total / totalExpenses * 100 : 0
                return CategoryTotal(name: slice.name, amount: slice.total, percentOfExpenses: pct)
            }

        return SpendingSummary(
            month: monthLabel(for: monthFilter),
            currency: currency,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            balance: totalIncome - totalExpenses,
            transactionCount: transactionCount,
            topCategories: categoryTotals
        )
    }

    private static func monthLabel(for filter: MonthFilter) -> String {
        filter.startOfMonth.formatted(.dateTime.month(.wide).year())
    }
}
