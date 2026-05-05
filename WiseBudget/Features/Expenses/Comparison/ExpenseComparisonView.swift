import SwiftUI
import SwiftData
import Charts

struct ExpenseComparisonView: View {
    // Internal transfers stay in history but are excluded from every comparison surface.
    @Query(filter: #Predicate<Expense> { !$0.isInternalTransfer }, sort: \Expense.date) private var allExpenses: [Expense]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    var onSelectMonth: ((MonthKey) -> Void)? = nil

    enum TimeRange: String, CaseIterable, Identifiable {
        case sixMonths = "6 Months"
        case year = "Year"
        case lifetime = "Lifetime"

        var id: Self { self }
    }

    @State private var timeRange: TimeRange = .sixMonths

    // MARK: - Filtered Months

    private var monthRange: [MonthKey] {
        switch timeRange {
        case .sixMonths:
            return MonthKey.recent(6, endingAt: MonthKey(year: filter.year, month: filter.month))
        case .year:
            return MonthKey.allMonths(of: filter.year)
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
        case .year:      .month
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
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "calendar")
                }
                .menuIndicator(.hidden)
                .help("Time Range")
                .accessibilityLabel("Time Range")
            }
        }
    }
}

#Preview {
    ExpenseComparisonView(filter: MonthFilter(year: 2026, month: 3))
        .modelContainer(for: [Expense.self, ExpenseCategory.self], inMemory: true)
        .frame(width: 600, height: 500)
}
