import SwiftUI
import SwiftData
import Charts

struct ExpenseCategoryChartView: View {
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var selectedCategory: String?
    @State private var selectedAngle: Double?

    let filter: MonthFilter

    init(filter: MonthFilter) {
        self.filter = filter

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    // MARK: - Data

    private struct CategorySlice: Identifiable {
        let id = UUID()
        let name: String
        let total: Double
    }

    private var slices: [CategorySlice] {
        let grouped = Dictionary(grouping: expenses) { expense in
            expense.category?.name ?? "Uncategorized"
        }

        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { total, expense in
                if expense.currency == defaultCurrency {
                    return total + expense.amount
                } else if let baseAmount = expense.baseCurrencyAmount,
                          expense.baseCurrency == defaultCurrency {
                    return total + baseAmount
                }
                return total
            }
            return CategorySlice(name: name, total: NSDecimalNumber(decimal: sum).doubleValue)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    private var grandTotal: Double {
        slices.reduce(0) { $0 + $1.total }
    }

    private func categoryForAngle(_ angle: Double) -> String? {
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.total
            if angle <= cumulative {
                return slice.name
            }
        }
        return nil
    }

    // MARK: - Body

    var body: some View {
        if slices.isEmpty {
            ContentUnavailableView("No Expenses", systemImage: "chart.pie")
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    chartView
                    legendView
                }
                .padding()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    selectedCategory = nil
                }
            }
        }
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Amount", slice.total),
                innerRadius: .ratio(0.5),
                angularInset: 1
            )
            .foregroundStyle(by: .value("Category", slice.name))
            .opacity(selectedCategory == nil || selectedCategory == slice.name ? 1.0 : 0.3)
        }
        .chartLegend(.hidden)
        .chartAngleSelection(value: $selectedAngle)
        .onChange(of: selectedAngle) { _, newValue in
            if let newValue {
                selectedCategory = categoryForAngle(newValue)
            }
        }
        .frame(height: 300)
    }

    // MARK: - Legend

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slices) { slice in
                HStack {
                    Text(slice.name)
                        .fontWeight(selectedCategory == slice.name ? .bold : .regular)
                    Spacer()
                    Text(String(format: "%.1f%%", slice.total / grandTotal * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("\(Decimal(slice.total), format: .number) \(defaultCurrency)")
                        .monospacedDigit()
                        .frame(minWidth: 80, alignment: .trailing)
                }
                .opacity(selectedCategory == nil || selectedCategory == slice.name ? 1.0 : 0.5)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation {
                        if selectedCategory == slice.name {
                            selectedCategory = nil
                        } else {
                            selectedCategory = slice.name
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
