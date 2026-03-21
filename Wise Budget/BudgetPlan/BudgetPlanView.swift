import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter

    var body: some View {
        BudgetPlanQueryListView(
            filter: monthFilter,
            selectedSidebarItem: $selectedSidebarItem,
            monthFilter: $monthFilter
        )
        .id(monthFilter)
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
        }
    }
}

extension FocusedValues {
    @Entry var resetBudgetPlan: (() -> Void)? = nil
}

#Preview {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        BudgetPlanView(selectedSidebarItem: .constant(.budgetPlan), monthFilter: .constant(MonthFilter(year: 2025, month: 1)))
    }
    .modelContainer(PreviewSampleData.container)
}

