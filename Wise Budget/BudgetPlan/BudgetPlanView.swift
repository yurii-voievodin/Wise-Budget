import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter

    @State private var selectedTab: BudgetPlanTab = .plan

    enum BudgetPlanTab: Hashable {
        case plan
        case chart
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Budget Plan", systemImage: "list.bullet", value: .plan) {
                BudgetPlanQueryListView(
                    filter: monthFilter,
                    selectedSidebarItem: $selectedSidebarItem,
                    monthFilter: $monthFilter
                )
                .id(monthFilter)
            }
            Tab("Chart", systemImage: "chart.bar", value: .chart) {
                BudgetPlanChartView(filter: monthFilter)
                    .id(monthFilter)
            }
        }
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

