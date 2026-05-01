import SwiftUI
import Charts

enum CategoryChartSortOrder: String {
    case bySpending
    case byCategoryOrder
}

struct CategoryChartSection: View {
    let slices: [CategoryChartSlice]
    let currency: String
    let emptyText: String
    var colorMap: [String: Color] = [:]
    var sortIndex: ((String) -> Int)? = nil
    var onSelect: ((String) -> Void)? = nil

    /// Persisted per-screen via `@AppStorage` so the user's sort choice survives
    /// app restarts and re-renders. Tied to a stable `storageKey` per call site
    /// (e.g. dashboard vs. income) so each surface remembers independently.
    @AppStorage private var sortOrder: CategoryChartSortOrder

    init(
        slices: [CategoryChartSlice],
        currency: String,
        emptyText: String,
        colorMap: [String: Color] = [:],
        sortIndex: ((String) -> Int)? = nil,
        sortOrderStorageKey: String,
        defaultSortOrder: CategoryChartSortOrder = .bySpending,
        onSelect: ((String) -> Void)? = nil
    ) {
        self.slices = slices
        self.currency = currency
        self.emptyText = emptyText
        self.colorMap = colorMap
        self.sortIndex = sortIndex
        self.onSelect = onSelect
        self._sortOrder = AppStorage(wrappedValue: defaultSortOrder, sortOrderStorageKey)
    }

    private var grandTotal: Double {
        slices.reduce(0) { $0 + $1.total }
    }

    private var sortedSlices: [CategoryChartSlice] {
        switch sortOrder {
        case .bySpending:
            return slices.sorted { $0.total > $1.total }
        case .byCategoryOrder:
            guard let sortIndex else { return slices }
            return slices.sorted { sortIndex($0.name) < sortIndex($1.name) }
        }
    }

    var body: some View {
        Section {
            if slices.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.secondary)
            } else {
                Chart(sortedSlices) { slice in
                    SectorMark(
                        angle: .value("Amount", slice.total),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(by: .value("Category", slice.name))
                }
                .chartForegroundStyleScale(domain: sortedSlices.map(\.name), range: sortedSlices.map { colorMap[$0.name] ?? .gray })
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

                ForEach(sortedSlices) { slice in
                    if let onSelect {
                        Button {
                            onSelect(slice.name)
                        } label: {
                            sliceRow(slice)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    } else {
                        sliceRow(slice)
                    }
                }
            }
        } header: {
            HStack {
                Text("By Category")
                Spacer()
                if sortIndex != nil && !slices.isEmpty {
                    sortMenu
                }
            }
        }
    }

    @ViewBuilder
    private func sliceRow(_ slice: CategoryChartSlice) -> some View {
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

    private var sortMenu: some View {
        Menu("Sort order", systemImage: "arrow.up.arrow.down") {
            Picker("Sort", selection: $sortOrder) {
                Text("By Spending").tag(CategoryChartSortOrder.bySpending)
                Text("By Category").tag(CategoryChartSortOrder.byCategoryOrder)
            }
            .pickerStyle(.inline)
        }
        .labelStyle(.iconOnly)
        .font(.caption)
        .textCase(nil)
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
            colorMap: ["Groceries": .green, "Transport": .blue, "Entertainment": .purple],
            sortIndex: { name in
                ["Groceries", "Transport", "Entertainment"].firstIndex(of: name) ?? 99
            },
            sortOrderStorageKey: "previewCategoryChartSortOrder",
            onSelect: { _ in }
        )
    }
    .frame(width: 500, height: 500)
}
