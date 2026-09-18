import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @Query private var budgetPlans: [BudgetPlan]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @Binding var monthFilter: MonthFilter
    var onSelectCategory: (String) -> Void
    var onAddExpense: () -> Void
    var onConnectBank: () -> Void

    @State private var hasAnyExpenses = true
    @State private var hasAnyIncomes = true
    @State private var hasKeychainTokens = false

    init(
        monthFilter: Binding<MonthFilter>,
        onSelectCategory: @escaping (String) -> Void = { _ in },
        onAddExpense: @escaping () -> Void = {},
        onConnectBank: @escaping () -> Void = {}
    ) {
        self._monthFilter = monthFilter
        self.onSelectCategory = onSelectCategory
        self.onAddExpense = onAddExpense
        self.onConnectBank = onConnectBank

        let startDate = monthFilter.wrappedValue.startOfMonth
        let endDate = monthFilter.wrappedValue.startOfNextMonth
        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate && !expense.isInternalTransfer
            },
            sort: \.date,
            order: .reverse
        )

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate && !income.isInternalTransfer
            },
            sort: \.date,
            order: .reverse
        )

        let filterYear = monthFilter.wrappedValue.year
        let filterMonth = monthFilter.wrappedValue.month
        self._budgetPlans = Query(
            filter: #Predicate<BudgetPlan> { plan in
                plan.year == filterYear && plan.month == filterMonth
            }
        )
    }

    var body: some View {
        Group {
            if isCurrentMonthEmpty {
                DashboardEmptyStateView(
                    state: isFirstLaunchEmptyState ? .onboarding : .noTransactionsThisMonth,
                    onAddExpense: onAddExpense,
                    onConnectBank: onConnectBank
                )
            } else {
                DashboardContent(
                    summary: spendingSummary,
                    metrics: metrics,
                    scopeKey: insightsScopeKey,
                    currency: defaultCurrency,
                    recentTransactions: recentTransactions,
                    expenseSlices: expenseSlices,
                    monthFilter: monthFilter,
                    expenseCount: expenses.count,
                    onSelectCategory: onSelectCategory
                )
            }
        }
        .task { checkForAnyTransactions() }
    }

    private var isCurrentMonthEmpty: Bool {
        expenses.isEmpty && incomes.isEmpty
    }

    private var isFirstLaunchEmptyState: Bool {
        !hasAnyExpenses && !hasAnyIncomes && !hasConnectedBank
    }

    private var hasConnectedBank: Bool {
        !monobankConnectedName.isEmpty || !wiseConnectedName.isEmpty || hasKeychainTokens
    }

    private var plannedBudgetForPacing: Decimal? {
        guard let plan = budgetPlans.first else { return nil }
        if let monthlyBudget = plan.monthlyBudget, monthlyBudget > .zero {
            return monthlyBudget
        }
        let totalPlanned = plan.items.reduce(Decimal.zero) { $0 + $1.plannedAmount }
        return totalPlanned > .zero ? totalPlanned : nil
    }

    private var metrics: DashboardMetrics {
        DashboardMetrics(
            monthFilter: monthFilter,
            totalIncome: incomes.reduce(.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) },
            totalExpenses: expenses.reduce(.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) },
            plannedBudget: plannedBudgetForPacing
        )
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

    private var spendingSummary: SpendingSummary {
        SpendingSummary.build(
            monthFilter: monthFilter,
            currency: defaultCurrency,
            expenses: expenses,
            incomes: incomes
        )
    }

    private var insightsScopeKey: String {
        MonthScopeKey.make(year: monthFilter.year, month: monthFilter.month)
    }

    private var recentTransactions: [DashboardRecentTransaction] {
        let expenseItems = expenses.prefix(5).map {
            DashboardRecentTransaction(
                id: $0.persistentModelID,
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
                id: $0.persistentModelID,
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

    private func checkForAnyTransactions() {
        hasAnyExpenses = ((try? modelContext.fetchCount(FetchDescriptor<Expense>())) ?? 0) > 0
        hasAnyIncomes = ((try? modelContext.fetchCount(FetchDescriptor<Income>())) ?? 0) > 0
        hasKeychainTokens =
            KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }
}

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.container)
        .environment(LocalAIAppDetector())
        .frame(width: 600, height: 600)
}

#Preview("Budget Pacing") {
    @Previewable @State var filter = MonthFilter.currentMonth()
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.overspendingPaceContainer)
        .environment(LocalAIAppDetector())
        .frame(width: 600, height: 700)
}
