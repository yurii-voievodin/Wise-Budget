import SwiftUI
import SwiftData
import Charts

struct BudgetPlanChartView: View {
    @Query private var plans: [BudgetPlan]
    @Query private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter

    init(filter: MonthFilter) {
        self.filter = filter

        let filterYear = filter.year
        let filterMonth = filter.month

        self._plans = Query(
            filter: #Predicate<BudgetPlan> { plan in
                plan.year == filterYear && plan.month == filterMonth
            }
        )

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            }
        )
    }

    private var currentPlan: BudgetPlan? {
        plans.first
    }

    private var planCurrency: String {
        currentPlan?.currency ?? defaultCurrency
    }

    private func actualSpending(for category: ExpenseCategory) -> Decimal {
        expenses
            .filter { $0.category?.persistentModelID == category.persistentModelID }
            .reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: planCurrency) ?? Decimal.zero) }
    }

    private func plannedAmount(for category: ExpenseCategory) -> Decimal {
        currentPlan?.items.first {
            $0.category?.persistentModelID == category.persistentModelID
        }?.plannedAmount ?? Decimal.zero
    }

    private var chartData: [BudgetChartEntry] {
        categories.compactMap { category in
            let planned = plannedAmount(for: category)
            let actual = actualSpending(for: category)
            guard planned > 0 || actual > 0 else { return nil }
            return BudgetChartEntry(
                categoryName: category.name,
                iconName: category.displayIconName,
                planned: Double(truncating: planned as NSDecimalNumber),
                actual: Double(truncating: actual as NSDecimalNumber)
            )
        }
        .sorted { $0.planned > $1.planned }
    }

    var body: some View {
        if chartData.isEmpty {
            ContentUnavailableView(
                "No Budget Data",
                systemImage: "chart.bar",
                description: Text("Add planned amounts or record expenses to see the chart.")
            )
        } else {
            Form {
                Section("Planned vs Spent") {
                    Chart(chartData) { entry in
                        BarMark(
                            x: .value("Amount", entry.planned),
                            y: .value("Category", entry.categoryName)
                        )
                        .foregroundStyle(by: .value("Type", "Planned"))

                        BarMark(
                            x: .value("Amount", entry.actual),
                            y: .value("Category", entry.categoryName)
                        )
                        .foregroundStyle(by: .value("Type", "Spent"))
                    }
                    .chartForegroundStyleScale([
                        "Planned": Color.blue,
                        "Spent": Color.orange
                    ])
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                        }
                    }
                    .frame(height: CGFloat(chartData.count) * 50 + 40)
                    .padding(.vertical, 8)
                }

                Section("Details") {
                    ForEach(chartData) { entry in
                        HStack {
                            Label(entry.categoryName, systemImage: entry.iconName)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Planned: \(Decimal(entry.planned), format: .number) \(planCurrency)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("Spent: \(Decimal(entry.actual), format: .number) \(planCurrency)")
                                    .font(.caption)
                                    .foregroundStyle(entry.actual > entry.planned && entry.planned > 0 ? .red : .orange)
                            }
                            .monospacedDigit()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct BudgetChartEntry: Identifiable {
    let id = UUID()
    let categoryName: String
    let iconName: String
    let planned: Double
    let actual: Double
}
