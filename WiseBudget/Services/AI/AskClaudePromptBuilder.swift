import Foundation

/// Builds the Markdown payload that is copied to the clipboard when the user
/// taps "Ask Claude" on the Dashboard. Pure value-in / string-out so the
/// behaviour is trivially testable without spinning up SwiftData.
enum AskClaudePromptBuilder {

    static func build(
        monthFilter: MonthFilter,
        currentMonthExpenses: [Expense],
        baseCurrency: String,
        responseLanguageName: String? = nil
    ) -> String {
        let currentTitle = monthTitle(for: monthFilter)

        var lines: [String] = []
        lines.append(intro(currentTitle: currentTitle, baseCurrency: baseCurrency, responseLanguageName: responseLanguageName))
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

    private static func intro(currentTitle: String, baseCurrency: String, responseLanguageName: String?) -> String {
        var text = """
        Base currency: \(baseCurrency).
        """
        if let language = responseLanguageName, !language.isEmpty {
            text += "\nPlease respond in \(language)."
        }
        return text
    }

    private static func transactionTable(for expenses: [Expense], baseCurrency: String) -> String {
        let header = "| Date       | Category | Amount (base) | Amount (origin) | Description |"
        let divider = "|------------|----------|---------------|---------------|-------------|"

        guard !expenses.isEmpty else {
            return [header, divider, "| _no transactions this month_ |  |  |  |  |"].joined(separator: "\n")
        }

        let sorted = expenses.sorted { $0.date < $1.date }
        var rows: [String] = [header, divider]
        for expense in sorted {
            let dateString = dateFormatter.string(from: expense.date)
            let category = sanitizeForCell(expense.category?.name ?? "Uncategorized")
            let baseAmount = formatBaseAmount(expense, baseCurrency: baseCurrency)
            let originalAmount = formatOriginalAmount(expense, baseCurrency: baseCurrency)
            let description = sanitizeForCell(expense.descriptionText ?? expense.destination ?? "")
            rows.append("| \(dateString) | \(category) | \(baseAmount) | \(originalAmount) | \(description) |")
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Formatting

    private static func monthTitle(for filter: MonthFilter) -> String {
        let comps = DateComponents(year: filter.year, month: filter.month, day: 1)
        let date = Calendar.current.date(from: comps) ?? Date.now
        return date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "en_US_POSIX")))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

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

    private static func sanitizeForCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}
