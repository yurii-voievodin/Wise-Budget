import SwiftUI
import Charts

struct CategoryChartSlice: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let total: Double
}

struct CategoryChartSection: View {
    let slices: [CategoryChartSlice]
    let currency: String
    let emptyText: String

    private var grandTotal: Double {
        slices.reduce(0) { $0 + $1.total }
    }

    var body: some View {
        Section("By Category") {
            if slices.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            } else {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.total),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Category", slice.name))
                }
                .chartLegend(.hidden)
                .frame(height: 150)
                .padding(.vertical, 8)

                ForEach(slices) { slice in
                    HStack {
                        Label(slice.name, systemImage: slice.iconName)
                        Spacer()
                        Text(String(format: "%.1f%%", slice.total / grandTotal * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("\(Decimal(slice.total), format: .number) \(currency)")
                            .monospacedDigit()
                            .frame(minWidth: 80, alignment: .trailing)
                    }
                }
            }
        }
    }
}
