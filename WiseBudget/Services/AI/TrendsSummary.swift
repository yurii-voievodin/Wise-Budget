import Foundation

/// Compact, LLM-friendly snapshot of spending across multiple months.
/// Fed to the Foundation Models prompt when generating trends narratives.
struct TrendsSummary: Codable, Sendable {
    struct MonthTotals: Codable, Sendable {
        let label: String                    // "Nov 2025"
        let total: Double
        let byCategory: [String: Double]
    }

    let rangeLabel: String                   // "Last 6 months" or "2026"
    let currency: String
    let months: [MonthTotals]

    var isEmpty: Bool {
        months.allSatisfy { $0.total == 0 }
    }

    /// Compact plain-text rendering for the Foundation Models prompt.
    /// Avoids JSON punctuation tokens to reduce input-token count and latency.
    func encodedAsPrompt() -> String {
        var lines: [String] = []
        lines.append("Range: \(rangeLabel) (\(currency))")
        for month in months {
            lines.append("\(month.label): total \(String(format: "%.2f", month.total))")
            let sorted = month.byCategory.sorted { $0.value > $1.value }
            for (name, amount) in sorted {
                lines.append("  - \(name): \(String(format: "%.2f", amount))")
            }
        }
        return lines.joined(separator: "\n")
    }
}

extension TrendsSummary {
    /// Builds a trends summary from expenses filtered to the given month range.
    /// - Parameters:
    ///   - rangeLabel: human-readable label used in the prompt header.
    ///   - currency: the user's default currency used for conversion.
    ///   - months: ordered list of months to include (ascending).
    ///   - expenses: the full expense set; filtered internally to the month range.
    static func build(
        rangeLabel: String,
        currency: String,
        months: [MonthKey],
        expenses: [Expense]
    ) -> TrendsSummary {
        let calendar = Calendar.current
        let validMonths = Set(months)

        var totals: [MonthKey: (total: Double, byCategory: [String: Double])] =
            Dictionary(uniqueKeysWithValues: months.map { ($0, (0, [:])) })

        for expense in expenses {
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            guard let year = components.year, let month = components.month else { continue }
            let key = MonthKey(year: year, month: month)
            guard validMonths.contains(key) else { continue }

            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: currency) ?? .zero).doubleValue
            guard amount > 0 else { continue }

            let categoryName = expense.category?.name ?? "Uncategorized"
            totals[key]?.total += amount
            totals[key]?.byCategory[categoryName, default: 0] += amount
        }

        let monthSummaries = months.map { key -> MonthTotals in
            let bucket = totals[key] ?? (0, [:])
            return MonthTotals(
                label: key.fullLabel,
                total: bucket.total,
                byCategory: bucket.byCategory
            )
        }

        return TrendsSummary(
            rangeLabel: rangeLabel,
            currency: currency,
            months: monthSummaries
        )
    }
}
