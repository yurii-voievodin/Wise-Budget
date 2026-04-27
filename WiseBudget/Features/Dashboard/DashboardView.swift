import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @Binding var monthFilter: MonthFilter
    var onSelectCategory: (String) -> Void

    @State private var expenseToEdit: Expense?
    @State private var incomeToEdit: Income?
    @State private var askAIToastProvider: AIProvider?
    @State private var askAIToastTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(monthFilter: Binding<MonthFilter>, onSelectCategory: @escaping (String) -> Void = { _ in }) {
        self._monthFilter = monthFilter
        self.onSelectCategory = onSelectCategory

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

    private var sortedExpenseSlices: [CategoryChartSlice] {
        expenseSlices.sorted { DefaultExpenseCategory.sortIndex(for: $0.name) < DefaultExpenseCategory.sortIndex(for: $1.name) }
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

    private var insightsScopeKey: String {
        MonthScopeKey.make(year: monthFilter.year, month: monthFilter.month)
    }

    private var recentTransactions: [DashboardRecentTransaction] {
        let expenseItems = expenses.prefix(5).map {
            DashboardRecentTransaction(
                descriptionText: $0.descriptionText,
                categoryName: $0.category?.name,
                categoryIcon: $0.category?.displayIconName,
                item: $0,
                isExpense: true,
                date: $0.date
            )
        }
        let incomeItems = incomes.prefix(5).map {
            DashboardRecentTransaction(
                descriptionText: $0.descriptionText,
                categoryName: $0.category?.name,
                categoryIcon: $0.category?.displayIconName,
                item: $0,
                isExpense: false,
                date: $0.date
            )
        }
        return Array(
            (expenseItems + incomeItems)
                .sorted { $0.date > $1.date }
                .prefix(5)
        )
    }

    // MARK: - Body

    var body: some View {
        if expenses.isEmpty && incomes.isEmpty {
            DashboardEmptyStateView()
        } else {
            Form {
                MonthlyInsightsCard(summary: spendingSummary, scopeKey: insightsScopeKey)
                DashboardMonthSummarySection(
                    totalIncome: totalIncome,
                    totalExpenses: totalExpenses,
                    balance: balance,
                    currency: defaultCurrency
                )
                DashboardDailyAveragesSection(
                    incomeDailyAverage: incomeDailyAverage,
                    expenseDailyAverage: expenseDailyAverage,
                    dailyBalance: dailyBalance,
                    currency: defaultCurrency
                )
                if shouldShowBudgetPacing {
                    DashboardBudgetPacingSection(
                        daysRemainingInMonth: daysRemainingInMonth,
                        dailyAllowance: dailyAllowance,
                        currency: defaultCurrency
                    )
                }
                if !expenseSlices.isEmpty {
                    CategoryChartSection(
                        slices: sortedExpenseSlices,
                        currency: defaultCurrency,
                        emptyText: "No expenses",
                        colorMap: DefaultExpenseCategory.chartColorMap
                    )
                    DashboardTopCategoriesSection(
                        slices: topCategories,
                        totalExpenses: totalExpenses,
                        currency: defaultCurrency,
                        onSelect: onSelectCategory
                    )
                }
                DashboardRecentTransactionsSection(transactions: recentTransactions) { transaction in
                    if let expense = transaction.item as? Expense {
                        expenseToEdit = expense
                    } else if let income = transaction.item as? Income {
                        incomeToEdit = income
                    }
                }
            }
            .formStyle(.grouped)
            .sheet(item: $expenseToEdit) { expense in
                ExpenseFormSheet(expense: expense) { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                    withAnimation {
                        expense.amount = amount
                        expense.currency = currency
                        expense.date = date
                        expense.category = category
                        expense.descriptionText = descriptionText
                        expense.destination = destination
                        expense.baseCurrencyAmount = baseCurrencyAmount
                        expense.baseCurrency = baseCurrency
                    }
                }
            }
            .sheet(item: $incomeToEdit) { income in
                IncomeFormSheet(income: income) { amount, currency, date, category, descriptionText, source, baseCurrencyAmount, baseCurrency in
                    withAnimation {
                        income.amount = amount
                        income.currency = currency
                        income.date = date
                        income.category = category
                        income.descriptionText = descriptionText
                        income.source = source
                        income.baseCurrencyAmount = baseCurrencyAmount
                        income.baseCurrency = baseCurrency
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let provider = askAIToastProvider {
                    AIHandoffCopiedToast(provider: provider)
                        .padding(.bottom, 24)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .toolbar {
                AskAIToolbar(
                    filter: monthFilter,
                    expenseCount: expenses.count,
                    onCopied: presentAskAIToast
                )
            }
        }
    }

    private func presentAskAIToast(provider: AIProvider) {
        askAIToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            askAIToastProvider = provider
        }
        askAIToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                askAIToastProvider = nil
            }
        }
    }
}

private struct AIHandoffCopiedToast: View {
    let provider: AIProvider

    var body: some View {
        Label("Copied — paste in \(provider.displayName) with ⌘V", systemImage: "doc.on.clipboard")
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .shadow(radius: 6, y: 2)
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
