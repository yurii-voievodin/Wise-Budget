import SwiftUI
import SwiftData

struct ExpenseStatisticsView: View {
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    init(filter: MonthFilter) {
        self.filter = filter

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    // MARK: - Computed Statistics

    private var totalInDefaultCurrency: Decimal {
        expenses.reduce(Decimal.zero) { total, expense in
            if expense.currency == defaultCurrency {
                return total + expense.amount
            } else if let baseAmount = expense.baseCurrencyAmount,
                      expense.baseCurrency == defaultCurrency {
                return total + baseAmount
            }
            return total
        }
    }

    private var categoryBreakdown: [(name: String, total: Decimal, percentage: Double)] {
        let grouped = Dictionary(grouping: expenses) { expense in
            expense.category?.name ?? "Uncategorized"
        }

        let totals: [(name: String, total: Decimal)] = grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { total, expense in
                if expense.currency == defaultCurrency {
                    return total + expense.amount
                } else if let baseAmount = expense.baseCurrencyAmount,
                          expense.baseCurrency == defaultCurrency {
                    return total + baseAmount
                }
                return total
            }
            return (name: name, total: sum)
        }

        let grandTotal = totalInDefaultCurrency
        return totals
            .map { item in
                let pct = grandTotal > 0
                    ? NSDecimalNumber(decimal: item.total / grandTotal * 100).doubleValue
                    : 0
                return (name: item.name, total: item.total, percentage: pct)
            }
            .sorted { $0.total > $1.total }
    }

    private var currencyBreakdown: [(currency: String, total: Decimal)] {
        let grouped = Dictionary(grouping: expenses, by: \.currency)
        let totals = grouped.map { currency, items in
            let sum = items.reduce(Decimal.zero) { $0 + $1.amount }
            return (currency: currency, total: sum)
        }
        // Default currency first, then the rest sorted by total descending
        return totals.sorted { lhs, rhs in
            if lhs.currency == defaultCurrency { return true }
            if rhs.currency == defaultCurrency { return false }
            return lhs.total > rhs.total
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            overviewSection
            categorySection
            if currencyBreakdown.count > 1 {
                currencySection
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Sections

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Transactions") {
                Text("\(expenses.count)")
            }
            LabeledContent("Total (\(defaultCurrency))") {
                Text("\(totalInDefaultCurrency, format: .number) \(defaultCurrency)")
                    .fontWeight(.semibold)
            }
        }
    }

    private var categorySection: some View {
        Section("By Category") {
            if categoryBreakdown.isEmpty {
                Text("No expenses")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categoryBreakdown, id: \.name) { item in
                    LabeledContent {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f%%", item.percentage))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text("\(item.total, format: .number) \(defaultCurrency)")
                                .monospacedDigit()
                        }
                    } label: {
                        Text(item.name)
                    }
                }
            }
        }
    }

    private var currencySection: some View {
        Section("By Currency") {
            ForEach(currencyBreakdown, id: \.currency) { item in
                LabeledContent(item.currency) {
                    Text("\(item.total, format: .number) \(item.currency)")
                        .monospacedDigit()
                }
            }
        }
    }

}
