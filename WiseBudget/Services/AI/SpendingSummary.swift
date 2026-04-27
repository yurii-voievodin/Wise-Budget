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

    /// One transaction line in the encoded prompt. Dates are deliberately
    /// omitted — the on-device model gets the most signal per token from the
    /// amount, category, and merchant/source label.
    struct LineItem: Codable, Sendable {
        let amount: Double       // unsigned magnitude
        let category: String
        let label: String?       // merchant / source / note, truncated
    }

    let month: String           // e.g. "March 2026"
    let currency: String        // e.g. "EUR"
    let totalIncome: Double
    let totalExpenses: Double
    let balance: Double
    let transactionCount: Int
    let topCategories: [CategoryTotal]
    /// Raw income lines fed to the model so it can spot paycheck timing,
    /// irregular income, etc. Defaulted for the legacy memberwise initializer
    /// still used by tests that only care about totals.
    var incomes: [LineItem] = []
    /// Raw expense lines fed to the model so it can spot recurring merchants,
    /// outsized one-offs, weekday-vs-weekend patterns, etc.
    var expenses: [LineItem] = []

    private static let labelMaxChars = 30

    func encodedAsPrompt() -> String {
        var lines: [String] = []
        lines.append("Month: \(month) (\(currency))")
        lines.append("Income: \(Self.formatAmount(totalIncome))")
        lines.append("Expenses: \(Self.formatAmount(totalExpenses))")
        lines.append("Balance: \(Self.formatAmount(balance))")
        let savingsPct = totalIncome > 0
            ? Int(((totalIncome - totalExpenses) / totalIncome * 100).rounded())
            : 0
        lines.append("Savings: \(savingsPct)%")
        lines.append("Transactions: \(transactionCount)")

        if !incomes.isEmpty {
            lines.append("")
            lines.append("Income transactions (amount, category, source):")
            for item in incomes.sorted(by: { $0.amount > $1.amount }) {
                lines.append(Self.renderLine(item, sign: "+"))
            }
        }

        if !expenses.isEmpty {
            lines.append("")
            lines.append("Expense transactions (amount, category, merchant):")
            for item in expenses.sorted(by: { $0.amount > $1.amount }) {
                lines.append(Self.renderLine(item, sign: "-"))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func renderLine(_ item: LineItem, sign: String) -> String {
        let label = item.label.map { "  \($0)" } ?? ""
        return "\(sign)\(formatAmount(item.amount))  \(item.category)\(label)"
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
    /// Used by the Dashboard, unit tests, and any caller that has the raw
    /// transactions on hand.
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

        let incomeItems: [LineItem] = incomes.compactMap { income in
            let amount = NSDecimalNumber(decimal: income.convertedAmount(to: currency) ?? .zero).doubleValue
            guard amount > 0 else { return nil }
            return LineItem(
                amount: amount,
                category: income.category?.name ?? "Uncategorized",
                label: trimmedLabel(income.source, fallback: income.descriptionText)
            )
        }

        let expenseItems: [LineItem] = expenses.compactMap { expense in
            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: currency) ?? .zero).doubleValue
            guard amount > 0 else { return nil }
            return LineItem(
                amount: amount,
                category: expense.category?.name ?? "Uncategorized",
                label: trimmedLabel(expense.destination, fallback: expense.descriptionText)
            )
        }

        return build(
            monthFilter: monthFilter,
            currency: currency,
            totalIncome: NSDecimalNumber(decimal: totalIncome).doubleValue,
            totalExpenses: NSDecimalNumber(decimal: totalExpenses).doubleValue,
            transactionCount: expenses.count + incomes.count,
            expenseSlices: slices,
            incomes: incomeItems,
            expenses: expenseItems,
            topCategoryLimit: topCategoryLimit
        )
    }

    /// Builds a summary from already-computed totals and category slices, plus
    /// optional raw transaction lines. Preferred when the caller (e.g. the
    /// Dashboard) has already grouped the data for charts.
    static func build(
        monthFilter: MonthFilter,
        currency: String,
        totalIncome: Double,
        totalExpenses: Double,
        transactionCount: Int,
        expenseSlices: [CategoryChartSlice],
        incomes: [LineItem] = [],
        expenses: [LineItem] = [],
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
            topCategories: categoryTotals,
            incomes: incomes,
            expenses: expenses
        )
    }

    private static func monthLabel(for filter: MonthFilter) -> String {
        filter.startOfMonth.formatted(.dateTime.month(.wide).year())
    }

    private static func trimmedLabel(_ primary: String?, fallback: String?) -> String? {
        let raw = (primary ?? fallback)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return String(raw.prefix(Self.labelMaxChars))
    }
}
