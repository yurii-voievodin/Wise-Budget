import SwiftUI
import SwiftData

extension FocusedValues {
    @Entry var selectedMonthFilter: MonthFilter? = nil
}

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var monthFilter: MonthFilter = .stored
    @State private var expenseCategoryFilter: String?
    @State private var expenseListTab: ExpenseListView.ExpenseTab = .calendar
    @State private var incomeListTab: IncomeListView.IncomeTab = .incomes
    @State private var syncService = BankSyncService()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(OnboardingFlowView.completedKey) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        NavigationSplitView {
            SidebarList(
                selectedSidebarItem: $selectedSidebarItem,
                syncService: syncService,
                monthFilter: monthFilter
            )
        } detail: {
            detail
        }
        .focusedSceneValue(\.selectedMonthFilter, monthFilter)
        .task { autoSync() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { autoSync() }
        }
        .onChange(of: monthFilter) { _, newValue in
            newValue.persist()
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed { syncService.refreshConnectionStatus() }
        }
        .onChange(of: selectedSidebarItem) { oldValue, _ in
            resetFilters(leaving: oldValue)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSidebarItem {
        case .dashboard:
            DashboardView(
                monthFilter: $monthFilter,
                onSelectCategory: showExpenses(inCategory:),
                onAddExpense: showExpenseList,
                onConnectBank: showBankConnections
            )
            .id(monthFilter)
            .navigationTitle("")
            .toolbar {
                MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
            }
        case .budgetPlan:
            BudgetPlanView(
                selectedSidebarItem: $selectedSidebarItem,
                monthFilter: $monthFilter,
                expenseCategoryFilter: $expenseCategoryFilter
            )
        case .expenses:
            ExpenseListView(
                filter: $monthFilter,
                selectedSidebarItem: $selectedSidebarItem,
                selectedCategoryName: $expenseCategoryFilter,
                selectedTab: $expenseListTab,
                syncService: syncService
            )
        case .income:
            IncomeListView(
                filter: $monthFilter,
                selectedSidebarItem: $selectedSidebarItem,
                selectedTab: $incomeListTab,
                syncService: syncService
            )
        case .cashflow:
            CashflowView(
                filter: monthFilter,
                onSelectExpenseMonth: showExpenses(forMonth:),
                onSelectIncomeMonth: showIncome(forMonth:)
            )
            .toolbar {
                MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
            }
        case .lifetime:
            LifetimeView()
        case .bankConnections:
            BankConnectionsView(syncService: syncService)
        }
    }

    private func showExpenses(inCategory categoryName: String) {
        expenseCategoryFilter = categoryName
        expenseListTab = .expenses
        selectedSidebarItem = .expenses
    }

    private func showExpenseList() {
        expenseCategoryFilter = nil
        expenseListTab = .expenses
        selectedSidebarItem = .expenses
    }

    private func showExpenses(forMonth month: MonthKey) {
        monthFilter = monthFilter.with(monthKey: month)
        expenseListTab = .expenses
        selectedSidebarItem = .expenses
    }

    private func showIncome(forMonth month: MonthKey) {
        monthFilter = monthFilter.with(monthKey: month)
        selectedSidebarItem = .income
    }

    private func showBankConnections() {
        selectedSidebarItem = .bankConnections
    }

    private func resetFilters(leaving previousItem: SidebarItem) {
        if previousItem == .expenses || previousItem == .income {
            monthFilter.foreignOnly = false
        }
        if previousItem == .expenses {
            expenseCategoryFilter = nil
            expenseListTab = .calendar
        }
        if previousItem == .income {
            incomeListTab = .incomes
        }
    }

    private func autoSync() {
        syncService.autoSyncIfNeeded(context: modelContext)
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
