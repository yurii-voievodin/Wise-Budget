import SwiftUI
import SwiftData
import Charts

struct IncomeComparisonView: View {
    // Internal transfers stay in history but are excluded from every comparison surface.
    @Query(filter: #Predicate<Income> { !$0.isInternalTransfer }, sort: \Income.date) private var allIncomes: [Income]
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
            let keys = Set(allIncomes.compactMap { income -> MonthKey? in
                let c = calendar.dateComponents([.year, .month], from: income.date)
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

    private var chartData: [ComparisonChartDataPoint] {
        let calendar = Calendar.current
        let validMonths = Set(monthRange)

        let filtered = allIncomes.filter { income in
            let c = calendar.dateComponents([.year, .month], from: income.date)
            guard let year = c.year, let month = c.month else { return false }
            return validMonths.contains(MonthKey(year: year, month: month))
        }

        var grouped: [MonthKey: [String: Double]] = [:]
        for income in filtered {
            let c = calendar.dateComponents([.year, .month], from: income.date)
            guard let year = c.year, let month = c.month else { continue }
            let key = MonthKey(year: year, month: month)
            let cat = income.category?.name ?? "Uncategorized"
            let amount = NSDecimalNumber(decimal: income.convertedAmount(to: defaultCurrency) ?? .zero).doubleValue
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
            return DefaultIncomeCategory.sortIndex(for: $0.categoryName) < DefaultIncomeCategory.sortIndex(for: $1.categoryName)
        }
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

    // MARK: - Body

    var body: some View {
        Form {
            if chartData.isEmpty {
                Section {
                    Text("No income data for this period")
                        .foregroundStyle(.secondary)
                }
            } else {
                ComparisonChartSection(
                    title: "Income by Category",
                    chartData: chartData,
                    xMonths: monthRange,
                    labelStyle: labelStyle,
                    colorDomain: DefaultIncomeCategory.chartColorDomain,
                    colorRange: DefaultIncomeCategory.chartColorRange
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
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    IncomeComparisonView(filter: MonthFilter(year: 2026, month: 3))
        .modelContainer(for: [Income.self, IncomeCategory.self], inMemory: true)
        .frame(width: 600, height: 500)
}
