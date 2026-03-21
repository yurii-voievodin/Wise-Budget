import SwiftUI
import SwiftData

struct ExpenseStatisticsView: View {
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, syncService: BankSyncService) {
        self.filter = filter
        self.syncService = syncService

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

    // MARK: - Chart Data

    private var slices: [CategoryChartSlice] {
        let grouped = Dictionary(grouping: expenses) { expense in
            expense.category?.name ?? "Uncategorized"
        }

        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { total, expense in
                if expense.currency == defaultCurrency {
                    return total + expense.amount
                } else if let baseAmount = expense.baseCurrencyAmount,
                          expense.baseCurrency == defaultCurrency {
                    return total + baseAmount
                }
                return total
            }
            let icon = items.first?.category?.displayIconName ?? "folder"
            return CategoryChartSlice(name: name, iconName: icon, total: NSDecimalNumber(decimal: sum).doubleValue)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
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
        if expenses.isEmpty {
            emptyStateView
        } else {
            Form {
                categoryChartSection
                overviewSection
                if currencyBreakdown.count > 1 {
                    currencySection
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Sections

    private var emptyStateView: some View {
        MonthEmptyStateView(
            title: "No Expenses This Month",
            systemImage: "chart.pie",
            filter: filter,
            syncService: syncService
        )
    }

    private var categoryChartSection: some View {
        CategoryChartSection(slices: slices, currency: defaultCurrency, emptyText: "No expenses")
    }

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
