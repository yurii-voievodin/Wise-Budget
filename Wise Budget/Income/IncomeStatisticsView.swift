import SwiftUI
import SwiftData

struct IncomeStatisticsView: View {
    @Query private var incomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, syncService: BankSyncService) {
        self.filter = filter
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    // MARK: - Chart Data

    private var slices: [CategoryChartSlice] {
        let grouped = Dictionary(grouping: incomes) { income in
            income.category?.name ?? "Uncategorized"
        }

        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { total, income in
                if income.currency == defaultCurrency {
                    return total + income.amount
                } else if let baseAmount = income.baseCurrencyAmount,
                          income.baseCurrency == defaultCurrency {
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
        incomes.reduce(Decimal.zero) { total, income in
            if income.currency == defaultCurrency {
                return total + income.amount
            } else if let baseAmount = income.baseCurrencyAmount,
                      income.baseCurrency == defaultCurrency {
                return total + baseAmount
            }
            return total
        }
    }

    private var currencyBreakdown: [(currency: String, total: Decimal)] {
        let grouped = Dictionary(grouping: incomes, by: \.currency)
        let totals = grouped.map { currency, items in
            let sum = items.reduce(Decimal.zero) { $0 + $1.amount }
            return (currency: currency, total: sum)
        }
        return totals.sorted { lhs, rhs in
            if lhs.currency == defaultCurrency { return true }
            if rhs.currency == defaultCurrency { return false }
            return lhs.total > rhs.total
        }
    }

    // MARK: - Body

    var body: some View {
        if incomes.isEmpty {
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
            title: "No Income This Month",
            systemImage: "chart.pie",
            filter: filter,
            syncService: syncService
        )
    }

    private var categoryChartSection: some View {
        CategoryChartSection(slices: slices, currency: defaultCurrency, emptyText: "No income")
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Transactions") {
                Text("\(incomes.count)")
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
