import SwiftUI
import SwiftData
import Charts

struct IncomeCategoryChartView: View {
    @Query private var incomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    init(filter: MonthFilter) {
        self.filter = filter

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
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
        let grouped = Dictionary(grouping: incomes) { income in
            income.category?.name ?? "Uncategorized"
        }

        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { total, income in
                if income.currency == defaultCurrency {
                    return total + income.amount
                } else if let baseAmount = income.baseCurrencyAmount,
                          income.baseCurrency == defaultCurrency {
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

    // MARK: - Body

    var body: some View {
        if slices.isEmpty {
            ContentUnavailableView("No Income", systemImage: "chart.pie")
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    chartView
                    legendView
                }
                .padding()
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
        }
        .chartLegend(.hidden)
        .frame(height: 300)
    }

    // MARK: - Legend

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slices) { slice in
                HStack {
                    Text(slice.name)
                    Spacer()
                    Text(String(format: "%.1f%%", slice.total / grandTotal * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("\(Decimal(slice.total), format: .number) \(defaultCurrency)")
                        .monospacedDigit()
                        .frame(minWidth: 80, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal)
    }
}
