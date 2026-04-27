import Foundation

/// Compact, LLM-friendly snapshot of one month of spending.
/// Built on the Dashboard and rendered as a compact plain-text block for the
/// Foundation Models prompt. Plain text instead of JSON saves input tokens
/// (no braces, quotes, or repeated keys), which directly cuts time-to-first-token.
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

    func encodedAsPrompt() -> String {
        var lines: [String] = []
        lines.append("Month: \(month) (\(currency))")
        lines.append("Income: \(Self.formatAmount(totalIncome))")
        lines.append("Expenses: \(Self.formatAmount(totalExpenses))")
        lines.append("Balance: \(Self.formatAmount(balance))")
        lines.append("Transactions: \(transactionCount)")
        if !topCategories.isEmpty {
            lines.append("Top categories:")
            for cat in topCategories {
                lines.append("- \(cat.name): \(Self.formatAmount(cat.amount)) (\(Self.formatPercent(cat.percentOfExpenses))%)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func formatAmount(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f", value)
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
