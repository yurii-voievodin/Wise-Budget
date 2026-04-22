import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var monthFilter: MonthFilter = .currentMonth()
    @State private var expenseCategoryFilter: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Overview") {
                    ForEach([SidebarItem.dashboard, .budgetPlan, .expenses, .income, .comparison], id: \.self) { item in
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
                DashboardView(monthFilter: $monthFilter)
                    .id(monthFilter)
                    .toolbar {
                        MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                    }
            case .budgetPlan:
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, monthFilter: $monthFilter, expenseCategoryFilter: $expenseCategoryFilter)
            case .expenses:
                ExpenseListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $expenseCategoryFilter)
            case .income:
                IncomeListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem)
            case .comparison:
                ExpenseComparisonView(filter: monthFilter)
                    .toolbar {
                        MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                    }
            case .bankConnections:
                BankConnectionsView()
            }
        }
        .onChange(of: selectedSidebarItem) { oldValue, newValue in
            if oldValue == .expenses || oldValue == .income {
                monthFilter.foreignOnly = false
            }
            if oldValue == .expenses {
                expenseCategoryFilter = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
