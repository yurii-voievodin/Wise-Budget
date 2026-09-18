import SwiftUI
import Charts

struct ComparisonChartSection: View {
    let title: LocalizedStringKey
    let chartData: [ComparisonChartDataPoint]
    let xMonths: [MonthKey]
    let labelStyle: MonthKey.ChartLabelStyle
    let colorDomain: [String]
    let colorRange: [Color]
    var hidesLegend: Bool = false

    @State private var hoveredCategory: String? = nil
    @State private var hoverLocation: CGPoint? = nil
    @State private var hoveredAmount: Double = 0

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
        let colorScale = resolvedColorScale
        let pointsByMonthLabel = Dictionary(grouping: chartData) { $0.monthKey.chartLabel(labelStyle) }

        Section(title) {
            Chart(chartData) { point in
                BarMark(
                    x: .value("Month", point.monthKey.chartLabel(labelStyle)),
                    y: .value("Amount", point.total)
                )
                .foregroundStyle(by: .value("Category", point.categoryName))
                .opacity(hoveredCategory == nil || hoveredCategory == point.categoryName ? 1.0 : 0.25)
            }
            .chartForegroundStyleScale(domain: colorScale.domain, range: colorScale.range)
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(.rect)
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                updateHover(
                                    at: location,
                                    proxy: proxy,
                                    geo: geo,
                                    domain: colorScale.domain,
                                    pointsByMonthLabel: pointsByMonthLabel
                                )
                            case .ended:
                                hoveredCategory = nil
                                hoverLocation = nil
                            }
                        }

                    if let location = hoverLocation, let category = hoveredCategory {
                        tooltip(category: category, amount: hoveredAmount)
                            .position(tooltipPosition(at: location, in: geo.size))
                    }
                }
            }
            .frame(minHeight: 250)
            .padding(.vertical, Layout.Spacing.small)
            .animation(Motion.hover, value: hoveredCategory)
        }
    }

    @ViewBuilder
    private func tooltip(category: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category)
                .font(.caption)
                .bold()
            Text(Decimal(amount), format: .number.precision(.fractionLength(0)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, Layout.Spacing.small)
        .padding(.vertical, Layout.Spacing.snug)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Layout.Radius.small))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.Radius.small)
                .strokeBorder(.separator, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        .allowsHitTesting(false)
        .fixedSize()
    }

    private func tooltipPosition(at location: CGPoint, in size: CGSize) -> CGPoint {
        let offsetY: CGFloat = -28
        let clampedX = min(max(location.x, 60), size.width - 60)
        let y = max(location.y + offsetY, 24)
        return CGPoint(x: clampedX, y: y)
    }

    private func updateHover(
        at location: CGPoint,
        proxy: ChartProxy,
        geo: GeometryProxy,
        domain: [String],
        pointsByMonthLabel: [String: [ComparisonChartDataPoint]]
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geo[plotFrameAnchor]
        let xInPlot = location.x - plotFrame.minX
        let yInPlot = location.y - plotFrame.minY

        guard xInPlot >= 0, xInPlot <= plotFrame.width,
              yInPlot >= 0, yInPlot <= plotFrame.height,
              let monthLabel: String = proxy.value(atX: xInPlot),
              let amountAtY: Double = proxy.value(atY: yInPlot),
              amountAtY >= 0 else {
            hoveredCategory = nil
            hoverLocation = nil
            return
        }

        let stacked = (pointsByMonthLabel[monthLabel] ?? [])
            .sorted {
                (domain.firstIndex(of: $0.categoryName) ?? .max)
                    < (domain.firstIndex(of: $1.categoryName) ?? .max)
            }

        var cumulative: Double = 0
        for point in stacked {
            cumulative += point.total
            if amountAtY <= cumulative {
                hoveredCategory = point.categoryName
                hoveredAmount = point.total
                hoverLocation = location
                return
            }
        }
        hoveredCategory = nil
        hoverLocation = nil
    }
}
