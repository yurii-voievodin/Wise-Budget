import SwiftUI
import SwiftData
import Charts

struct ExpenseComparisonView: View {
    // Internal transfers stay in history but are excluded from every comparison surface.
    @Query(filter: #Predicate<Expense> { !$0.isInternalTransfer }, sort: \Expense.date) private var allExpenses: [Expense]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    @Binding var timeRange: CashflowTimeRange
    var onSelectMonth: ((MonthKey) -> Void)? = nil

    init(
        filter: MonthFilter,
        timeRange: Binding<CashflowTimeRange> = .constant(.sixMonths),
        onSelectMonth: ((MonthKey) -> Void)? = nil
    ) {
        self.filter = filter
        self._timeRange = timeRange
        self.onSelectMonth = onSelectMonth
    }

    // MARK: - Filtered Months

    private var monthRange: [MonthKey] {
        switch timeRange {
        case .sixMonths:
            return MonthKey.recent(6, endingAt: MonthKey(year: filter.year, month: filter.month))
        case .year:
            return MonthKey.recent(12, endingAt: MonthKey(year: filter.year, month: filter.month))
        case .lifetime:
            let calendar = Calendar.current
            let keys = Set(allExpenses.compactMap { expense -> MonthKey? in
                let c = calendar.dateComponents([.year, .month], from: expense.date)
                guard let year = c.year, let month = c.month else { return nil }
                return MonthKey(year: year, month: month)
            })
            return keys.sorted()
        }
    }

    private var labelStyle: MonthKey.ChartLabelStyle {
        switch timeRange {
        case .sixMonths: .monthYear
        case .year:      .monthYear
        case .lifetime:  .yearAtJanuary
        }
    }

    // MARK: - Chart Data

    private static let totalSeriesName = "Total"

    private var aggregatesTotalsOnly: Bool {
        timeRange == .lifetime
    }

    private var chartData: [ComparisonChartDataPoint] {
        let calendar = Calendar.current
        let validMonths = Set(monthRange)

        let filtered = allExpenses.filter { expense in
            let c = calendar.dateComponents([.year, .month], from: expense.date)
            guard let year = c.year, let month = c.month else { return false }
            return validMonths.contains(MonthKey(year: year, month: month))
        }

        var grouped: [MonthKey: [String: Double]] = [:]
        for expense in filtered {
            let c = calendar.dateComponents([.year, .month], from: expense.date)
            guard let year = c.year, let month = c.month else { continue }
            let key = MonthKey(year: year, month: month)
            let cat = aggregatesTotalsOnly ? Self.totalSeriesName : (expense.category?.name ?? "Uncategorized")
            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: defaultCurrency) ?? .zero).doubleValue
            grouped[key, default: [:]][cat, default: 0] += amount
        }

        var points: [ComparisonChartDataPoint] = []
        for (monthKey, categories) in grouped {
            for (cat, total) in categories where total > 0 {
                points.append(ComparisonChartDataPoint(monthKey: monthKey, categoryName: cat, total: total))
            }
        }
        return points.sorted {
            if $0.monthKey != $1.monthKey {
                return $0.monthKey < $1.monthKey
            }
            return DefaultExpenseCategory.sortIndex(for: $0.categoryName) < DefaultExpenseCategory.sortIndex(for: $1.categoryName)
        }
    }

    private var chartColorDomain: [String] {
        aggregatesTotalsOnly ? [Self.totalSeriesName] : DefaultExpenseCategory.chartColorDomain
    }

    private var chartColorRange: [Color] {
        aggregatesTotalsOnly ? [.accentColor] : DefaultExpenseCategory.chartColorRange
    }

    private var monthTotals: [(month: MonthKey, total: Double)] {
        var totals: [MonthKey: Double] = [:]
        for point in chartData {
            totals[point.monthKey, default: 0] += point.total
        }
        return monthRange.map { key in
            (month: key, total: totals[key, default: 0])
        }
    }

    private var periodTotal: Double {
        monthTotals.reduce(0) { $0 + $1.total }
    }

    private var categorySlices: [CategoryChartSlice] {
        let calendar = Calendar.current
        let validMonths = Set(monthRange)

        var totals: [String: Double] = [:]
        for expense in allExpenses {
            let c = calendar.dateComponents([.year, .month], from: expense.date)
            guard let year = c.year, let month = c.month else { continue }
            guard validMonths.contains(MonthKey(year: year, month: month)) else { continue }
            let name = expense.category?.name ?? "Uncategorized"
            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: defaultCurrency) ?? .zero).doubleValue
            totals[name, default: 0] += amount
        }
        return totals.map { name, total in
            CategoryChartSlice(
                name: name,
                iconName: DefaultExpenseCategory(rawValue: name)?.iconName ?? "ellipsis.circle",
                total: total
            )
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            if chartData.isEmpty {
                Section {
                    Text("No expense data for this period")
                        .foregroundStyle(.secondary)
                }
            } else {
                ComparisonChartSection(
                    title: aggregatesTotalsOnly ? "Expense Totals" : "Expenses by Category",
                    chartData: chartData,
                    xMonths: monthRange,
                    labelStyle: labelStyle,
                    colorDomain: chartColorDomain,
                    colorRange: chartColorRange,
                    hidesLegend: aggregatesTotalsOnly
                )
                ComparisonPeriodTotalSection(
                    total: periodTotal,
                    currency: defaultCurrency
                )
                ComparisonBreakdownSection(
                    monthTotals: monthTotals,
                    currency: defaultCurrency,
                    onSelect: onSelectMonth
                )
                if timeRange != .lifetime {
                    CategoryChartSection(
                        title: "Top Expense Categories",
                        slices: categorySlices,
                        currency: defaultCurrency,
                        emptyText: "No expenses yet",
                        colorMap: DefaultExpenseCategory.chartColorMap,
                        sortOrderStorageKey: "cashflowExpenseCategorySortOrder",
                        hidesChart: true
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    ExpenseComparisonView(filter: MonthFilter(year: 2026, month: 3))
        .modelContainer(for: [Expense.self, ExpenseCategory.self], inMemory: true)
        .frame(width: 600, height: 500)
}
