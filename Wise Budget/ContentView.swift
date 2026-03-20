import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .expenses
    @State private var monthFilter: MonthFilter = .currentMonth()

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
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, monthFilter: $monthFilter)
            case .expenses:
                ExpenseListView(filter: $monthFilter)
            case .income:
                IncomeListView(filter: $monthFilter)

            }
        }
        .onChange(of: selectedSidebarItem) { oldValue, _ in
            if oldValue == .expenses || oldValue == .income {
                monthFilter.foreignOnly = false
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
