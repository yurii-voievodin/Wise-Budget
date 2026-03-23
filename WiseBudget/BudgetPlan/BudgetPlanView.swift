import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter
    @Binding var expenseCategoryFilter: String?

    @State private var selectedTab: BudgetPlanTab = .plan

    enum BudgetPlanTab: Hashable {
        case plan
        case chart
        case statistics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Budget Plan", systemImage: "list.bullet", value: .plan) {
                BudgetPlanQueryListView(
                    filter: monthFilter,
                    selectedSidebarItem: $selectedSidebarItem,
                    monthFilter: $monthFilter,
                    expenseCategoryFilter: $expenseCategoryFilter
                )
                .id(monthFilter)
            }
            Tab("Chart", systemImage: "chart.bar", value: .chart) {
                BudgetPlanChartView(filter: monthFilter)
                    .id(monthFilter)
            }
            Tab("Statistics", systemImage: "chart.line.uptrend.xyaxis", value: .statistics) {
                BudgetStatisticsView(filter: monthFilter)
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
        BudgetPlanView(selectedSidebarItem: .constant(.budgetPlan), monthFilter: .constant(MonthFilter(year: 2025, month: 1)), expenseCategoryFilter: .constant(nil))
    }
    .modelContainer(PreviewSampleData.container)
}

