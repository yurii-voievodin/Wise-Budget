import SwiftUI
import SwiftData
import Charts

struct ExpenseComparisonView: View {
    @Query(sort: \Expense.date) private var allExpenses: [Expense]
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    enum TimeRange: String, CaseIterable {
        case sixMonths = "6 Months"
        case year = "Year"
        case lifetime = "Lifetime"
    }

    @State private var timeRange: TimeRange = .sixMonths

    // MARK: - Data Types

    private struct MonthKey: Hashable, Comparable {
        let year: Int
        let month: Int

        var shortLabel: String {
            let df = DateFormatter()
            df.dateFormat = "MMM"
            let comps = DateComponents(year: year, month: month, day: 1)
            let date = Calendar.current.date(from: comps) ?? Date.now
            return df.string(from: date)
        }

        var fullLabel: String {
            let df = DateFormatter()
            df.dateFormat = "MMM yyyy"
            let comps = DateComponents(year: year, month: month, day: 1)
            let date = Calendar.current.date(from: comps) ?? Date.now
            return df.string(from: date)
        }

        func chartLabel(compact: Bool) -> String {
            compact ? shortLabel : fullLabel
        }

        var sortValue: Int { year * 12 + month }

        static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
            lhs.sortValue < rhs.sortValue
        }
    }

    private struct ChartDataPoint: Identifiable {
        let id = UUID()
        let monthKey: MonthKey
        let categoryName: String
        let total: Double
    }

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

    private var chartData: [ChartDataPoint] {
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

        var points: [ChartDataPoint] = []
        for (monthKey, categories) in grouped {
            for (cat, total) in categories where total > 0 {
                points.append(ChartDataPoint(monthKey: monthKey, categoryName: cat, total: total))
            }
        }
        return points.sorted {
            if $0.monthKey != $1.monthKey {
                return $0.monthKey < $1.monthKey
            }
            return DefaultExpenseCategory.sortIndex(for: $0.categoryName) < DefaultExpenseCategory.sortIndex(for: $1.categoryName)
        }
    }

    private var categoryTotals: [(name: String, total: Double)] {
        var totals: [String: Double] = [:]
        for point in chartData {
            totals[point.categoryName, default: 0] += point.total
        }
        return totals.map { (name: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
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

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
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
                chartSection
                monthBreakdownSection
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Chart

    private var chartSection: some View {
        Section("Expenses by Category") {
            Chart(chartData) { point in
                BarMark(
                    x: .value("Month", point.monthKey.chartLabel(compact: useCompactLabels)),
                    y: .value("Amount", point.total)
                )
                .foregroundStyle(by: .value("Category", point.categoryName))
            }
            .chartForegroundStyleScale(domain: DefaultExpenseCategory.chartColorDomain, range: DefaultExpenseCategory.chartColorRange)
            .chartXScale(domain: xDomain)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatAmount(v))
                        }
                    }
                }
            }
            .frame(minHeight: 250)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Breakdown

    private var monthBreakdownSection: some View {
        Section("Monthly Totals") {
            ForEach(monthTotals, id: \.month) { item in
                LabeledContent(item.month.fullLabel) {
                    Text("\(formatAmount(item.total)) \(defaultCurrency)")
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Helpers

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private func formatAmount(_ value: Double) -> String {
        Self.amountFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}
