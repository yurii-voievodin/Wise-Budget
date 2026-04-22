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
            let sum = items.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
            let icon = items.first?.category?.displayIconName ?? "folder"
            return CategoryChartSlice(name: name, iconName: icon, total: NSDecimalNumber(decimal: sum).doubleValue)
        }
        .filter { $0.total > 0 }
        .sorted { DefaultIncomeCategory.sortIndex(for: $0.name) < DefaultIncomeCategory.sortIndex(for: $1.name) }
    }

    // MARK: - Computed Statistics

    private var totalInDefaultCurrency: Decimal {
        incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: filter.startOfMonth)?.count ?? 30
    }

    private var dailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalInDefaultCurrency / Decimal(daysInMonth)
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
        CategoryChartSection(slices: slices, currency: defaultCurrency, emptyText: "No income", colorMap: DefaultIncomeCategory.chartColorMap)
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
            LabeledContent("Daily Average (\(defaultCurrency))") {
                Text("\(dailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
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

#Preview {
    IncomeStatisticsView(filter: MonthFilter(year: 2026, month: 3), syncService: BankSyncService())
        .modelContainer(PreviewSampleData.container)
        .frame(width: 600, height: 500)
}
