import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @Binding var monthFilter: MonthFilter

    init(monthFilter: Binding<MonthFilter>) {
        self._monthFilter = monthFilter

        let startDate = monthFilter.wrappedValue.startOfMonth
        let endDate = monthFilter.wrappedValue.startOfNextMonth
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

    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date.now)
        return monthFilter.year == now.year && monthFilter.month == now.month
    }

    private var daysElapsedInMonth: Int {
        guard isCurrentMonth else { return 0 }
        return Calendar.current.component(.day, from: Date.now)
    }

    private var daysRemainingInMonth: Int {
        guard isCurrentMonth else { return 0 }
        return max(daysInMonth - daysElapsedInMonth + 1, 0)
    }

    private var remainingBudget: Decimal {
        totalIncome - totalExpenses
    }

    private var dailyAllowance: Decimal {
        guard daysRemainingInMonth > 0 else { return .zero }
        return remainingBudget / Decimal(daysRemainingInMonth)
    }

    private var currentSpendPace: Decimal {
        guard daysElapsedInMonth > 0 else { return .zero }
        return totalExpenses / Decimal(daysElapsedInMonth)
    }

    private var shouldShowBudgetPacing: Bool {
        isCurrentMonth
            && remainingBudget > .zero
            && daysRemainingInMonth > 0
            && currentSpendPace > dailyAllowance
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

    private var spendingSummary: SpendingSummary {
        SpendingSummary.build(
            monthFilter: monthFilter,
            currency: defaultCurrency,
            totalIncome: NSDecimalNumber(decimal: totalIncome).doubleValue,
            totalExpenses: NSDecimalNumber(decimal: totalExpenses).doubleValue,
            transactionCount: expenses.count + incomes.count,
            expenseSlices: expenseSlices
        )
    }

    // MARK: - Body

    var body: some View {
        if expenses.isEmpty && incomes.isEmpty {
            emptyState
        } else {
            Form {
                MonthlyInsightsCard(summary: spendingSummary)
                summarySection
                dailyAveragesSection
                if shouldShowBudgetPacing {
                    budgetPacingSection
                }
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
        ContentUnavailableView {
            Label("No Data This Month", systemImage: "square.grid.2x2")
                .foregroundStyle(.secondary)
        } description: {
            Text("Add expenses or income to see your monthly overview.")
        }
    }

    private var summarySection: some View {
        Section("Month Summary") {
            HStack {
                Label("Income", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text("\(totalIncome, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            HStack {
                Label("Expenses", systemImage: "arrow.up.circle.fill")
                    .foregroundStyle(.red)
                Spacer()
                Text("\(totalExpenses, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            HStack {
                Label("Balance", systemImage: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .fontWeight(.semibold)
                    .foregroundStyle(balance >= .zero ? .green : .red)
                Spacer()
                Text("\(balance >= .zero ? "+" : "")\(balance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(balance >= .zero ? .green : .red)
            }
        }
    }

    private var dailyAveragesSection: some View {
        Section("Daily Averages") {
            HStack {
                Label("Income", systemImage: "arrow.down.circle")
                    .foregroundStyle(.green)
                Spacer()
                Text("\(incomeDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
            HStack {
                Label("Expenses", systemImage: "arrow.up.circle")
                    .foregroundStyle(.red)
                Spacer()
                Text("\(expenseDailyAverage, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            HStack {
                Label("Balance", systemImage: dailyBalance >= .zero ? "checkmark.circle" : "exclamationmark.circle")
                    .fontWeight(.semibold)
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
                Spacer()
                Text("\(dailyBalance >= .zero ? "+" : "")\(dailyBalance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(dailyBalance >= .zero ? .green : .red)
            }
        }
    }

    private var budgetPacingSection: some View {
        Section("Budget Pacing") {
            HStack {
                Label("Days Remaining", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(daysRemainingInMonth)")
                    .monospacedDigit()
            }
            HStack {
                Label("Daily Allowance", systemImage: "target")
                    .foregroundStyle(.orange)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(dailyAllowance, format: .number.precision(.fractionLength(2))) \(defaultCurrency)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(.orange)
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

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.container)
        .frame(width: 600, height: 600)
}

#Preview("Budget Pacing") {
    @Previewable @State var filter = MonthFilter.currentMonth()
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.overspendingPaceContainer)
        .frame(width: 600, height: 700)
}
