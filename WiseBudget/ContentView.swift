import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .expenses
    @State private var monthFilter: MonthFilter = .currentMonth()
    @State private var expenseCategoryFilter: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section {
                    ForEach([SidebarItem.budgetPlan, .expenses, .income], id: \.self) { item in
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
            case .budgetPlan:
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, monthFilter: $monthFilter, expenseCategoryFilter: $expenseCategoryFilter)
            case .expenses:
                ExpenseListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $expenseCategoryFilter)
            case .income:
                IncomeListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem)
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
