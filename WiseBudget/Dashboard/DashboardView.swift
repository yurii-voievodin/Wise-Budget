import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var budgetPlans: [BudgetPlan]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @Binding var monthFilter: MonthFilter

    init(monthFilter: Binding<MonthFilter>) {
        self._monthFilter = monthFilter

        let startDate = monthFilter.wrappedValue.startOfMonth
        let endDate = monthFilter.wrappedValue.startOfNextMonth
        let filterYear = monthFilter.wrappedValue.year
        let filterMonth = monthFilter.wrappedValue.month

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date,
            order: .reverse
        )

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date,
            order: .reverse
        )

        self._budgetPlans = Query(
            filter: #Predicate<BudgetPlan> { plan in
                plan.year == filterYear && plan.month == filterMonth
            }
        )
    }

    // MARK: - Computed

    private var totalExpenses: Decimal {
        expenses.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }

    private var totalIncome: Decimal {
        incomes.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }

    private var balance: Decimal {
        totalIncome - totalExpenses
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthFilter.startOfMonth)?.count ?? 30
    }

    private var expenseDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalExpenses / Decimal(daysInMonth)
    }

    private var incomeDailyAverage: Decimal {
        guard daysInMonth > 0 else { return .zero }
        return totalIncome / Decimal(daysInMonth)
    }

    private var dailyBalance: Decimal {
        incomeDailyAverage - expenseDailyAverage
    }

    private var currentPlan: BudgetPlan? {
        budgetPlans.first
    }

    private var totalPlanned: Decimal {
        currentPlan?.items.reduce(Decimal.zero) { $0 + $1.plannedAmount } ?? .zero
    }

    private var expenseSlices: [CategoryChartSlice] {
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
            let icon = items.first?.category?.displayIconName ?? "folder"
            return CategoryChartSlice(name: name, iconName: icon, total: NSDecimalNumber(decimal: sum).doubleValue)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    private var topCategories: [CategoryChartSlice] {
        Array(expenseSlices.prefix(5))
    }

    // MARK: - Body

    var body: some View {
        if expenses.isEmpty && incomes.isEmpty {
            emptyState
        } else {
            Form {
                summarySection
                dailyAveragesSection
                if !expenseSlices.isEmpty {
                    expenseChartSection
                    topCategoriesSection
                }
                recentTransactionsSection
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Data This Month")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add expenses or income to see your monthly overview.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summarySection: some View {
        Section("Month Summary") {
            LabeledContent("Income") {
                Text("\(totalIncome, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            LabeledContent("Expenses") {
                Text("\(totalExpenses, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            LabeledContent("Balance") {
                Text("\(balance >= .zero ? "+" : "")\(balance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(balance >= .zero ? .green : .red)
            }
            if let plan = currentPlan, totalPlanned > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Budget")
                        Spacer()
                        Text("\(totalExpenses, format: .number) / \(totalPlanned, format: .number) \(plan.currency)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    BudgetProgressBar(spent: totalExpenses, planned: totalPlanned)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var dailyAveragesSection: some View {
        Section("Daily Averages") {
            LabeledContent("Income") {
                Text("\(incomeDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            LabeledContent("Expenses") {
                Text("\(expenseDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            LabeledContent("Balance") {
                Text("\(dailyBalance >= .zero ? "+" : "")\(dailyBalance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
            }
        }
    }

    private var expenseChartSection: some View {
        CategoryChartSection(
            slices: expenseSlices.sorted { DefaultExpenseCategory.sortIndex(for: $0.name) < DefaultExpenseCategory.sortIndex(for: $1.name) },
            currency: defaultCurrency,
            emptyText: "No expenses",
            colorMap: DefaultExpenseCategory.chartColorMap
        )
    }

    private var topCategoriesSection: some View {
        Section("Top Spending") {
            ForEach(topCategories) { slice in
                HStack {
                    Image(systemName: slice.iconName)
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    Text(slice.name)
                    Spacer()
                    if totalExpenses > 0 {
                        Text(String(format: "%.0f%%", slice.total / NSDecimalNumber(decimal: totalExpenses).doubleValue * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Text("\(Decimal(slice.total), format: .number) \(defaultCurrency)")
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .frame(minWidth: 80, alignment: .trailing)
                }
            }
        }
    }

    private var recentTransactionsSection: some View {
        Section("Recent Transactions") {
            let recent = recentItems
            if recent.isEmpty {
                Text("No transactions this month")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Image(systemName: item.isExpense ? "arrow.up.circle" : "arrow.down.circle")
                            .foregroundStyle(item.isExpense ? .red : .green)
                            .frame(width: 20)
                        TransactionRowView(
                            descriptionText: item.description,
                            categoryName: item.categoryName,
                            categoryIcon: item.categoryIcon,
                            extraField: nil,
                            item: item.item
                        )
                    }
                }
            }
        }
    }

    private var recentItems: [(description: String?, categoryName: String?, categoryIcon: String?, item: CurrencyConvertible, isExpense: Bool)] {
        struct Dated {
            let date: Date
            let description: String?
            let categoryName: String?
            let categoryIcon: String?
            let item: CurrencyConvertible
            let isExpense: Bool
        }

        let expenseItems = expenses.prefix(5).map {
            Dated(date: $0.date, description: $0.descriptionText, categoryName: $0.category?.name, categoryIcon: $0.category?.displayIconName, item: $0, isExpense: true)
        }
        let incomeItems = incomes.prefix(5).map {
            Dated(date: $0.date, description: $0.descriptionText, categoryName: $0.category?.name, categoryIcon: $0.category?.displayIconName, item: $0, isExpense: false)
        }

        return (expenseItems + incomeItems)
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { (description: $0.description, categoryName: $0.categoryName, categoryIcon: $0.categoryIcon, item: $0.item, isExpense: $0.isExpense) }
    }
}
