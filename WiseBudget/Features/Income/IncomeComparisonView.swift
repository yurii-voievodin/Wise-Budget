import SwiftUI
import SwiftData
import Charts

struct IncomeComparisonView: View {
    // Internal transfers stay in history but are excluded from every comparison surface.
    @Query(filter: #Predicate<Income> { !$0.isInternalTransfer }, sort: \Income.date) private var allIncomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

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
            let keys = Set(allIncomes.compactMap { income -> MonthKey? in
                let c = calendar.dateComponents([.year, .month], from: income.date)
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
            Section {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }

            if chartData.isEmpty {
                Section {
                    Text("No income data for this period")
                        .foregroundStyle(.secondary)
                }
            } else {
                ComparisonChartSection(
                    title: "Income by Category",
                    chartData: chartData,
                    xDomain: xDomain,
                    useCompactLabels: useCompactLabels,
                    colorDomain: DefaultIncomeCategory.chartColorDomain,
                    colorRange: DefaultIncomeCategory.chartColorRange
                )
                ComparisonPeriodTotalSection(
                    total: periodTotal,
                    currency: defaultCurrency
                )
                ComparisonBreakdownSection(
                    monthTotals: monthTotals,
                    currency: defaultCurrency
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
