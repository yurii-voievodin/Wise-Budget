import SwiftUI
import SwiftData

extension FocusedValues {
    @Entry var selectedMonthFilter: MonthFilter? = nil
}

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var monthFilter: MonthFilter = .currentMonth()
    @State private var expenseCategoryFilter: String?
    @State private var expenseListTab: ExpenseListView.ExpenseTab = .calendar

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Overview") {
                    ForEach([SidebarItem.dashboard, .budgetPlan, .expenses, .income, .cashflow], id: \.self) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
                Section {
                    Label(SidebarItem.bankConnections.rawValue, systemImage: SidebarItem.bankConnections.systemImage)
                        .tag(SidebarItem.bankConnections)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedSidebarItem {
            case .dashboard:
                DashboardView(
                    monthFilter: $monthFilter,
                    onSelectCategory: { categoryName in
                        expenseCategoryFilter = categoryName
                        expenseListTab = .expenses
                        selectedSidebarItem = .expenses
                    },
                    onAddExpense: {
                        expenseCategoryFilter = nil
                        expenseListTab = .expenses
                        selectedSidebarItem = .expenses
                    },
                    onConnectBank: {
                        selectedSidebarItem = .bankConnections
                    }
                )
                .id(monthFilter)
                .toolbar {
                    MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                }
            case .budgetPlan:
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, monthFilter: $monthFilter, expenseCategoryFilter: $expenseCategoryFilter)
            case .expenses:
                ExpenseListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $expenseCategoryFilter, selectedTab: $expenseListTab)
            case .income:
                IncomeListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem)
            case .cashflow:
                CashflowView(filter: monthFilter)
                    .toolbar {
                        MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                    }
            case .bankConnections:
                BankConnectionsView()
            }
        }
        .focusedSceneValue(\.selectedMonthFilter, monthFilter)
        .onChange(of: selectedSidebarItem) { oldValue, newValue in
            if oldValue == .expenses || oldValue == .income {
                monthFilter.foreignOnly = false
            }
            if oldValue == .expenses {
                expenseCategoryFilter = nil
                expenseListTab = .calendar
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
