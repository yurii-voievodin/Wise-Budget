import SwiftUI
import SwiftData
import Charts

struct ExpenseComparisonView: View {
    @Query(sort: \Expense.date) private var allExpenses: [Expense]
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    enum TimeRange: String, CaseIterable, Identifiable {
        case sixMonths = "6 Months"
        case year = "Year"
        case lifetime = "Lifetime"

        var id: Self { self }
    }

    @State private var timeRange: TimeRange = .sixMonths

    // MARK: - Filtered Months

    private var monthRange: [MonthKey] {
        let calendar = Calendar.current
        switch timeRange {
        case .sixMonths:
            let current = MonthKey(year: filter.year, month: filter.month)
            return (0..<6).reversed().compactMap { offset in
                let comps = DateComponents(year: current.year, month: current.month - offset)
                guard let date = calendar.date(from: comps),
                      let year = calendar.dateComponents([.year, .month], from: date).year,
                      let month = calendar.dateComponents([.year, .month], from: date).month else { return nil }
                return MonthKey(year: year, month: month)
            }
        case .year:
            return (1...12).map { MonthKey(year: filter.year, month: $0) }
        case .lifetime:
            let keys = Set(allExpenses.compactMap { expense -> MonthKey? in
                let c = calendar.dateComponents([.year, .month], from: expense.date)
                guard let year = c.year, let month = c.month else { return nil }
                return MonthKey(year: year, month: month)
            })
            return keys.sorted()
        }
    }

    private var useCompactLabels: Bool {
        timeRange == .year
    }

    private var xDomain: [String] {
        monthRange.map { $0.chartLabel(compact: useCompactLabels) }
    }

    // MARK: - Chart Data

    private var chartData: [ExpenseComparisonChartDataPoint] {
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
            let cat = expense.category?.name ?? "Uncategorized"
            let amount = NSDecimalNumber(decimal: expense.convertedAmount(to: defaultCurrency) ?? .zero).doubleValue
            grouped[key, default: [:]][cat, default: 0] += amount
        }

        var points: [ExpenseComparisonChartDataPoint] = []
        for (monthKey, categories) in grouped {
            for (cat, total) in categories where total > 0 {
                points.append(ExpenseComparisonChartDataPoint(monthKey: monthKey, categoryName: cat, total: total))
            }
        }
        return points.sorted {
            if $0.monthKey != $1.monthKey {
                return $0.monthKey < $1.monthKey
            }
            return DefaultExpenseCategory.sortIndex(for: $0.categoryName) < DefaultExpenseCategory.sortIndex(for: $1.categoryName)
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

    // MARK: - Trends Insights

    private var trendsRangeLabel: String {
        switch timeRange {
        case .sixMonths: "Last 6 months"
        case .year: "\(filter.year)"
        case .lifetime: "Lifetime"
        }
    }

    private var trendsKind: CachedInsightKind? {
        switch timeRange {
        case .sixMonths: .trends6m
        case .year: .trendsYear
        case .lifetime: nil
        }
    }

    private var trendsScopeKey: String {
        switch timeRange {
        case .sixMonths: MonthScopeKey.make(year: filter.year, month: filter.month)
        case .year: "\(filter.year)"
        case .lifetime: "lifetime"
        }
    }

    private var trendsSummary: TrendsSummary {
        TrendsSummary.build(
            rangeLabel: trendsRangeLabel,
            currency: defaultCurrency,
            months: monthRange,
            expenses: allExpenses
        )
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if chartData.isEmpty {
                Section {
                    Text("No expense data for this period")
                        .foregroundStyle(.secondary)
                }
            } else {
                if let kind = trendsKind {
                    TrendsInsightsCard(
                        summary: trendsSummary,
                        kind: kind,
                        scopeKey: trendsScopeKey
                    )
                }
                ExpenseComparisonChartSection(
                    chartData: chartData,
                    xDomain: xDomain,
                    useCompactLabels: useCompactLabels
                )
                ExpenseComparisonBreakdownSection(
                    monthTotals: monthTotals,
                    currency: defaultCurrency
                )
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
