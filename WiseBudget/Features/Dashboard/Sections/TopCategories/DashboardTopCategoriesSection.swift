import SwiftUI

struct DashboardTopCategoriesSection: View {
    let slices: [CategoryChartSlice]
    let totalExpenses: Decimal
    let currency: String

    var body: some View {
        Section("Top Spending") {
            ForEach(slices) { slice in
                DashboardTopCategoryRow(
                    slice: slice,
                    totalExpenses: totalExpenses,
                    currency: currency
                )
            }
        }
    }
}

private struct DashboardTopCategoryRow: View {
    let slice: CategoryChartSlice
    let totalExpenses: Decimal
    let currency: String

    var body: some View {
        HStack {
            Image(systemName: slice.iconName)
                .frame(width: 24, alignment: .center)
                .foregroundStyle(.secondary)
            Text(slice.name)
            Spacer()
            if totalExpenses > 0 {
                let pct = slice.total / NSDecimalNumber(decimal: totalExpenses).doubleValue * 100
                Text("\(pct, format: .number.precision(.fractionLength(0)))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text("\(Decimal(slice.total), format: .number) \(currency)")
                .monospacedDigit()
                .fontWeight(.medium)
                .frame(minWidth: 80, alignment: .trailing)
        }
    }
}
