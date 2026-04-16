import SwiftUI
import Charts

struct ExpenseComparisonChartDataPoint: Identifiable {
    let id = UUID()
    let monthKey: MonthKey
    let categoryName: String
    let total: Double
}

struct ExpenseComparisonChartSection: View {
    let chartData: [ExpenseComparisonChartDataPoint]
    let xDomain: [String]
    let useCompactLabels: Bool

    var body: some View {
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
                            Text(Decimal(v), format: .number.precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .frame(minHeight: 250)
            .padding(.vertical, 8)
        }
    }
}
