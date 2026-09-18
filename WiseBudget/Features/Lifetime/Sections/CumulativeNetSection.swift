import SwiftUI
import Charts

struct CumulativeNetSection: View {
    let points: [LifetimeAggregate.CumulativePoint]

    var body: some View {
        Section("Cumulative Net") {
            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Net", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    .linearGradient(
                        colors: [.accentColor.opacity(0.35), .accentColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Net", point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .year)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.year())
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
            .chartXScale(range: .plotDimension(padding: 20))
            .frame(minHeight: 220)
            .padding(.vertical, Layout.Spacing.small)
        }
    }
}
