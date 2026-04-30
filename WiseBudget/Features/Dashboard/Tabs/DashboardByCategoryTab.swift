import SwiftUI

struct DashboardByCategoryTab: View {
    let expenseSlices: [CategoryChartSlice]
    let currency: String
    let onSelectCategory: (String) -> Void

    var body: some View {
        Form {
            CategoryChartSection(
                slices: expenseSlices,
                currency: currency,
                emptyText: "No expenses this month",
                colorMap: DefaultExpenseCategory.chartColorMap,
                sortIndex: DefaultExpenseCategory.sortIndex(for:),
                sortOrderStorageKey: "dashboardCategoryChartSortOrder",
                onSelect: onSelectCategory
            )
        }
        .formStyle(.grouped)
    }
}
