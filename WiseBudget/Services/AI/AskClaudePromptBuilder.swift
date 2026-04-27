import Foundation

/// Builds the Markdown payload that is copied to the clipboard when the user
/// taps "Ask AI" on the Dashboard. Pure value-in / string-out so the
/// behaviour is trivially testable without spinning up SwiftData.
///
/// The prompt is intentionally separate from `SpendingInsightsService` /
/// `TrendsInsightsService` Foundation Models prompts. Cloud chat models
/// (Claude / ChatGPT / Gemini) have richer capabilities — artifacts,
/// code interpreter, canvas — so this prompt asks for an inline chart
/// in addition to the narrative analysis. The on-device prompts and this
/// one will diverge further over time, so they live in separate files.
enum AskClaudePromptBuilder {

    static func build(
        monthFilter: MonthFilter,
        currentMonthExpenses: [Expense],
        baseCurrency: String,
        responseLanguageName: String? = nil
    ) -> String {
        let currentTitle = monthTitle(for: monthFilter)

        var lines: [String] = []
        lines.append(intro(baseCurrency: baseCurrency, responseLanguageName: responseLanguageName))
        lines.append("")
        lines.append("## Transactions — \(currentTitle)")
        lines.append("")
        lines.append(transactionTable(for: currentMonthExpenses, baseCurrency: baseCurrency))

        return lines.joined(separator: "\n")
    }

    /// Returns the English name of the user's preferred system language
    /// (e.g. `"Ukrainian"`, `"German"`). Returns `nil` when the system
    /// language is English — the prompt itself is in English so adding
    /// "Please respond in English." would be noise.
    static func systemResponseLanguageName() -> String? {
        guard let code = Locale.current.language.languageCode?.identifier else { return nil }
        guard code.lowercased() != "en" else { return nil }
        return Locale(identifier: "en_US_POSIX").localizedString(forLanguageCode: code)
    }

    // MARK: - Sections

    private static func intro(baseCurrency: String, responseLanguageName: String?) -> String {
        var lines: [String] = []
        lines.append("You are a personal-finance coach reviewing one month of my expense ledger. The transactions follow as a Markdown table. Base currency: \(baseCurrency).")
        if let language = responseLanguageName, !language.isEmpty {
            lines.append("Please respond in \(language).")
        }
        lines.append("")
        lines.append("Please:")
        lines.append("1. Surface insights I'm unlikely to spot on my own — recurring or subscription-like charges (the same merchant appearing multiple times), merchants I spend disproportionately on, and one-off large purchases versus ongoing patterns.")
        lines.append("2. Give me 2–3 concrete, specific recommendations I can act on. Reference real merchants and amounts from the data — no generic advice like \"make a budget\" or \"reduce dining out.\"")
        lines.append("3. Render a chart of spending by category for this month — a horizontal bar sorted by amount works well. Use whatever inline visualization tool you have (Claude artifact, ChatGPT code interpreter, Gemini canvas).")
        lines.append("")
        lines.append("Use \(baseCurrency) for all amounts in your reply. Don't invent numbers or merchants. If the data is too thin for a confident insight, say so briefly rather than guessing.")
        return lines.joined(separator: "\n")
    }

    private static func transactionTable(for expenses: [Expense], baseCurrency: String) -> String {
        let header = "| Category | Amount (base) | Amount (origin) | Description |"
        let divider = "|----------|---------------|-----------------|-------------|"

        guard !expenses.isEmpty else {
            return [header, divider, "| _no transactions this month_ |  |  |  |"].joined(separator: "\n")
        }

        // Sorted by base-currency amount descending so big-ticket items lead
        // the table — most useful for the model and stable for tests now
        // that dates have been stripped.
        let sorted = expenses.sorted { sortableAmount(for: $0, baseCurrency: baseCurrency) > sortableAmount(for: $1, baseCurrency: baseCurrency) }
        var rows: [String] = [header, divider]
        for expense in sorted {
            let category = sanitizeForCell(expense.category?.name ?? "Uncategorized")
            let baseAmount = formatBaseAmount(expense, baseCurrency: baseCurrency)
            let originalAmount = formatOriginalAmount(expense, baseCurrency: baseCurrency)
            let description = sanitizeForCell(expense.descriptionText ?? expense.destination ?? "")
            rows.append("| \(category) | \(baseAmount) | \(originalAmount) | \(description) |")
        }
        return rows.joined(separator: "\n")
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

    private static func formatDecimalAmount(_ value: Decimal) -> String {
        amountFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private static func formatBaseAmount(_ expense: Expense, baseCurrency: String) -> String {
        if let converted = expense.convertedAmount(to: baseCurrency) {
            return "\(formatDecimalAmount(converted)) \(baseCurrency)"
        }
        return "—"
    }

    private static func formatOriginalAmount(_ expense: Expense, baseCurrency: String) -> String {
        if expense.currency == baseCurrency {
            return "—"
        }
        return "\(formatDecimalAmount(expense.amount)) \(expense.currency)"
    }

    private static func sortableAmount(for expense: Expense, baseCurrency: String) -> Decimal {
        expense.convertedAmount(to: baseCurrency) ?? expense.amount
    }

    private static func sanitizeForCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
