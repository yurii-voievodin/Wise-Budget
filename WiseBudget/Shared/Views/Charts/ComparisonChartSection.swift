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
    let xMonths: [MonthKey]
    let labelStyle: MonthKey.ChartLabelStyle
    let colorDomain: [String]
    let colorRange: [Color]
    var hidesLegend: Bool = false

    private var xDomain: [String] {
        xMonths.map { $0.chartLabel(labelStyle) }
    }

    private var januaryTickValues: [String] {
        xMonths.filter { $0.month == 1 }.map { $0.chartLabel(labelStyle) }
    }

    private var januaryYearByLabel: [String: String] {
        Dictionary(uniqueKeysWithValues: xMonths.filter { $0.month == 1 }.map {
            ($0.chartLabel(labelStyle), $0.yearLabel)
        })
    }

    /// Charts traps when chart data contains a category not present in the
    /// foreground-style domain. Extend the domain with any stray categories
    /// and pad the range with a fallback color.
    private var resolvedColorScale: (domain: [String], range: [Color]) {
        let known = Set(colorDomain)
        var seen: Set<String> = []
        let extras = chartData.compactMap { point -> String? in
            guard !known.contains(point.categoryName), seen.insert(point.categoryName).inserted else { return nil }
            return point.categoryName
        }
        guard !extras.isEmpty else { return (colorDomain, colorRange) }
        return (colorDomain + extras, colorRange + Array(repeating: .gray, count: extras.count))
    }

    var body: some View {
        Section(title) {
            Chart(chartData) { point in
                BarMark(
                    x: .value("Month", point.monthKey.chartLabel(labelStyle)),
                    y: .value("Amount", point.total)
                )
                .foregroundStyle(by: .value("Category", point.categoryName))
            }
            .chartForegroundStyleScale(domain: resolvedColorScale.domain, range: resolvedColorScale.range)
            .chartXScale(domain: xDomain)
            .chartXAxis {
                switch labelStyle {
                case .yearAtJanuary:
                    AxisMarks(values: januaryTickValues) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let s = value.as(String.self), let year = januaryYearByLabel[s] {
                                Text(year)
                            }
                        }
                    }
                default:
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
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
            .chartLegend(hidesLegend ? .hidden : .visible)
            .frame(minHeight: 250)
            .padding(.vertical, 8)
        }
    }
}
