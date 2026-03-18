import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .budgetPlan
    @State private var expenseFilter: ExpenseFilter = .currentMonth()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            switch selectedSidebarItem {
            case .budgetPlan:
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, expenseFilter: $expenseFilter)
            case .expenses:
                ExpenseListView(expenseFilter: $expenseFilter)
            case .income:
                IncomeListView()
            case .settings:
                CategoryManagementView()
            }
        }
        .onChange(of: selectedSidebarItem) { _, newValue in
            if newValue != .expenses {
                expenseFilter.foreignOnly = false
                expenseFilter.planCurrency = nil
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
