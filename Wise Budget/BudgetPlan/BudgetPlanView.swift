import SwiftUI
import SwiftData

struct BudgetPlanView: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var monthFilter: MonthFilter

    var body: some View {
        BudgetPlanQueryListView(
            filter: monthFilter,
            selectedSidebarItem: $selectedSidebarItem
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

struct BudgetProgressBar: View {
    let spent: Decimal
    let planned: Decimal

    private var progress: Double {
        guard planned > 0 else { return 0 }
        return min(Double(truncating: spent as NSDecimalNumber) / Double(truncating: planned as NSDecimalNumber), 1.0)
    }

    private var isOverBudget: Bool {
        spent > planned
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOverBudget ? Color.red : Color.accentColor)
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}
#Preview {
    NavigationSplitView {
        Text("Sidebar")
    } detail: {
        BudgetPlanView(selectedSidebarItem: .constant(.budgetPlan), monthFilter: .constant(MonthFilter(year: 2025, month: 1)))
    }
    .modelContainer(PreviewSampleData.container)
}

