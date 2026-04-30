import Foundation

/// Builds the Markdown payload that is copied to the clipboard when the user
/// taps "Ask AI" on the Dashboard. The same payload feeds Claude, ChatGPT,
/// and Gemini (see `AIProvider`). Pure value-in / string-out so the
/// behaviour is trivially testable without spinning up SwiftData.
enum CloudAIPromptBuilder {

    static func build(
        monthFilter: MonthFilter,
        summary: SpendingSummary,
        baseCurrency: String,
        responseLanguageName: String? = nil
    ) -> String {
        let title = monthTitle(for: monthFilter)

        var lines: [String] = []
        lines.append(intro(baseCurrency: baseCurrency, responseLanguageName: responseLanguageName))
        lines.append("")
        lines.append("## Monthly summary — \(title)")
        lines.append("")
        lines.append(summarySection(summary, baseCurrency: baseCurrency))

        return lines.joined(separator: "\n")
    }

    static func systemResponseLanguageName() -> String? {
        for preferred in Locale.preferredLanguages {
            guard let code = Locale(identifier: preferred).language.languageCode?.identifier,
                  !code.isEmpty,
                  code.lowercased() != "en" else { continue }
            return Locale(identifier: "en_US_POSIX").localizedString(forLanguageCode: code)
        }
        return nil
    }

    // MARK: - Sections

    private static func intro(baseCurrency: String, responseLanguageName: String?) -> String {
        var lines: [String] = []
        lines.append("You are a personal-finance coach reviewing one month of my ledger. The data below lists every transaction grouped under its category, plus totals, income sources, subscription-like charges, and largest one-offs. Don't recompute totals — they're given. Base currency: \(baseCurrency). Please review this data and give me a recomendations, build charts if possible.")
        if let language = responseLanguageName, !language.isEmpty {
            lines.append("Please respond in \(language).")
        }
        return lines.joined(separator: "\n")
    }

    private static func summarySection(_ summary: SpendingSummary, baseCurrency: String) -> String {
        var lines: [String] = []

        let savingsPct: Int = summary.totalIncome > 0
            ? Int(((summary.totalIncome - summary.totalExpenses) / summary.totalIncome * 100).rounded())
            : 0

        lines.append("- Income: \(formatDoubleAmount(summary.totalIncome)) \(baseCurrency)")
        lines.append("- Expenses: \(formatDoubleAmount(summary.totalExpenses)) \(baseCurrency)")
        lines.append("- Balance: \(formatDoubleAmount(summary.balance)) \(baseCurrency)")
        lines.append("- Savings: \(savingsPct)%")
        lines.append("- Transactions: \(summary.transactionCount)")

        if !summary.topCategories.isEmpty {
            lines.append("")
            lines.append("### Spending by category")

            // List every transaction under its category
            let expensesByCategory = Dictionary(grouping: summary.expenses, by: \.category)

            for category in summary.topCategories {
                let pct = String(format: "%.0f", category.percentOfExpenses)
                lines.append("")
                lines.append("#### \(category.name) — \(formatDoubleAmount(category.amount)) \(baseCurrency) (\(pct)%)")

                let items = (expensesByCategory[category.name] ?? []).sorted { $0.amount > $1.amount }
                for item in items {
                    let suffix = item.label.map { " — \($0)" } ?? ""
                    lines.append("- \(formatDoubleAmount(item.amount)) \(baseCurrency)\(suffix)")
                }
            }
        }

        if !summary.incomes.isEmpty {
            lines.append("")
            lines.append("### Income sources")
            lines.append("")
            for item in summary.incomes.sorted(by: { $0.amount > $1.amount }) {
                lines.append("- \(formatDoubleAmount(item.amount)) \(baseCurrency) — \(item.category)\(labelSuffix(item.label))")
            }
        }

        if !summary.subscriptionLikeCharges.isEmpty {
            lines.append("")
            lines.append("### Subscription-like charges")
            lines.append("")
            for merchant in summary.subscriptionLikeCharges {
                lines.append(renderMerchantBullet(merchant, baseCurrency: baseCurrency))
            }
        }

        if !summary.largestOneOffs.isEmpty {
            lines.append("")
            lines.append("### Largest one-offs")
            lines.append("")
            for item in summary.largestOneOffs {
                lines.append("- \(formatDoubleAmount(item.amount)) \(baseCurrency) — \(item.category)\(labelSuffix(item.label))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func renderMerchantBullet(_ merchant: SpendingSummary.MerchantAggregate, baseCurrency: String) -> String {
        let categories = merchant.categories.joined(separator: ", ")
        return "- \(merchant.displayLabel) × \(merchant.count) = \(formatDoubleAmount(merchant.total)) \(baseCurrency) (avg \(formatDoubleAmount(merchant.averagePerCharge)) \(baseCurrency)) — \(categories)"
    }

    private static func labelSuffix(_ label: String?) -> String {
        guard let label, !label.isEmpty else { return "" }
        return " (\(label))"
    }

    // MARK: - Formatting

    private static func monthTitle(for filter: MonthFilter) -> String {
        let comps = DateComponents(year: filter.year, month: filter.month, day: 1)
        let date = Calendar.current.date(from: comps) ?? Date.now
        return date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_US_POSIX")))
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func formatDoubleAmount(_ value: Double) -> String {
        amountFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}
