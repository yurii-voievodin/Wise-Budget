import SwiftUI

struct LifetimeYearTableSection: View {
    let rows: [LifetimeAggregate.YearTotals]
    let currency: String

    var body: some View {
        Section("By Year") {
            Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Year").gridColumnAlignment(.leading)
                    Text("Income")
                    Text("Expenses")
                    Text("Net")
                    Text("Saved")
                    Text("Top Expense").gridColumnAlignment(.leading)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(rows.reversed()) { row in
                    GridRow {
                        Text(String(row.year))
                            .gridColumnAlignment(.leading)
                            .fontWeight(.semibold)
                        Text(amount: Decimal(row.income), currency: currency, precision: 0)
                        Text(amount: Decimal(row.expenses), currency: currency, precision: 0)
                        Text(amount: Decimal(row.net), currency: currency, precision: 0)
                            .foregroundStyle(row.net >= 0 ? Color.green : Color.red)
                        if let rate = row.savingsRate {
                            Text("\(rate * 100, format: .number.precision(.fractionLength(0)))%")
                                .foregroundStyle(rate >= 0 ? Color.primary : Color.red)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                        if let cat = row.topExpenseCategory {
                            Label(cat, systemImage: DefaultExpenseCategory(rawValue: cat)?.iconName ?? "ellipsis.circle")
                                .gridColumnAlignment(.leading)
                                .labelStyle(.titleAndIcon)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.leading)
                        }
                    }
                    .monospacedDigit()
                }
            }
            .padding(.vertical, 4)
        }
    }
}
