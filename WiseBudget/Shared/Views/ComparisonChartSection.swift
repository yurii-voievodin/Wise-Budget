import SwiftUI
import Charts

struct ComparisonChartDataPoint: Identifiable {
    let id = UUID()
    let monthKey: MonthKey
    let categoryName: String
    let total: Double
}

struct ComparisonChartSection: View {
    let title: LocalizedStringKey
    let chartData: [ComparisonChartDataPoint]
    let xDomain: [String]
    let useCompactLabels: Bool
    let colorDomain: [String]
    let colorRange: [Color]

    var body: some View {
        Section(title) {
            Chart(chartData) { point in
                BarMark(
                    x: .value("Month", point.monthKey.chartLabel(compact: useCompactLabels)),
                    y: .value("Amount", point.total)
                )
                .foregroundStyle(by: .value("Category", point.categoryName))
            }
            .chartForegroundStyleScale(domain: colorDomain, range: colorRange)
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
