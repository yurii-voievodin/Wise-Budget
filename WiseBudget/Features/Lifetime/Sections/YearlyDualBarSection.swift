import SwiftUI
import Charts

struct YearlyDualBarSection: View {
    let rows: [LifetimeAggregate.YearTotals]

    private static let incomeSeries = "Income"
    private static let expenseSeries = "Expenses"

    var body: some View {
        Section("Income vs Expenses by Year") {
            Chart {
                ForEach(rows) { row in
                    BarMark(
                        x: .value("Year", String(row.year)),
                        y: .value("Amount", row.income)
                    )
                    .foregroundStyle(by: .value("Series", Self.incomeSeries))
                    .position(by: .value("Series", Self.incomeSeries))

                    BarMark(
                        x: .value("Year", String(row.year)),
                        y: .value("Amount", row.expenses)
                    )
                    .foregroundStyle(by: .value("Series", Self.expenseSeries))
                    .position(by: .value("Series", Self.expenseSeries))
                }
            }
            .chartForegroundStyleScale(
                domain: [Self.incomeSeries, Self.expenseSeries],
                range: [.income, .expense]
            )
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
            .frame(minHeight: 260)
            .padding(.vertical, Layout.Spacing.small)
        }
    }
}
