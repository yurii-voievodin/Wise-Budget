import SwiftUI

struct LifetimeYearTableSection: View {
    let rows: [LifetimeAggregate.YearTotals]
    let currency: String

    var body: some View {
        Section {
            Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                GridRow {
                    Text("Year").gridColumnAlignment(.leading)
                    Text("Income \(currency)")
                    Text("Expenses \(currency)")
                    Text("Net \(currency)")
                    Text("Saved")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

                ForEach(rows.reversed()) { row in
                    Divider()
                        .gridCellColumns(5)

                    GridRow {
                        Text(String(row.year))
                            .gridColumnAlignment(.leading)
                            .fontWeight(.semibold)
                        Text(Decimal(row.income), format: .number.precision(.fractionLength(0)))
                        Text(Decimal(row.expenses), format: .number.precision(.fractionLength(0)))
                        Text(Decimal(row.net), format: .number.sign(strategy: .always(includingZero: false)).precision(.fractionLength(0)))
                            .foregroundStyle(row.net >= 0 ? Color.income : Color.expense)
                            .fontWeight(.medium)
                        if let rate = row.savingsRate {
                            Text("\(rate * 100, format: .number.precision(.fractionLength(0)))%")
                                .foregroundStyle(rate >= 0 ? Color.primary : Color.expense)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .monospacedDigit()
                    .padding(.vertical, 10)
                }
            }
        } header: {
            Text("By Year")
        }
    }
}

#Preview {
    Form {
        LifetimeYearTableSection(
            rows: [
                .init(year: 2022, income: 18_500, expenses: 12_300),
                .init(year: 2023, income: 32_400, expenses: 21_800),
                .init(year: 2024, income: 47_900, expenses: 38_600),
                .init(year: 2025, income: 56_200, expenses: 49_400),
                .init(year: 2026, income: 22_100, expenses: 27_500)
            ],
            currency: "EUR"
        )
    }
    .formStyle(.grouped)
    .frame(width: 700, height: 360)
}
