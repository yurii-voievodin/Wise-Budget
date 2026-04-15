import SwiftUI
import Charts

struct CategoryChartSection: View {
    let slices: [CategoryChartSlice]
    let currency: String
    let emptyText: String
    var colorMap: [String: Color] = [:]

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
                .chartForegroundStyleScale(domain: slices.map(\.name), range: slices.map { colorMap[$0.name] ?? .gray })
                .chartLegend(.hidden)
                .chartBackground { proxy in
                    GeometryReader { geo in
                        if let frame = proxy.plotFrame {
                            let rect = geo[frame]
                            VStack(spacing: 2) {
                                Text("\(Decimal(grandTotal), format: .number)")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                Text(currency)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .frame(height: 150)
                .padding(.vertical, 8)

                ForEach(slices) { slice in
                    HStack {
                        Circle()
                            .fill(colorMap[slice.name] ?? .gray)
                            .frame(width: 12, height: 12)
                        Label(slice.name, systemImage: slice.iconName)
                        Spacer()
                        let pct = slice.total / grandTotal * 100
                        Text("\(pct, format: .number.precision(.fractionLength(1)))%")
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

#Preview {
    List {
        CategoryChartSection(
            slices: [
                CategoryChartSlice(name: "Groceries", iconName: "cart", total: 320),
                CategoryChartSlice(name: "Transport", iconName: "car", total: 150),
                CategoryChartSlice(name: "Entertainment", iconName: "film", total: 80),
            ],
            currency: "USD",
            emptyText: "No expenses",
            colorMap: ["Groceries": .green, "Transport": .blue, "Entertainment": .purple]
        )
    }
    .frame(width: 500, height: 500)
}
