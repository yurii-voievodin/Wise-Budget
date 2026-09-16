import SwiftUI

struct CategoryChartSortMenu: View {
    @Binding var sortOrder: CategoryChartSortOrder

    var body: some View {
        Menu("Sort order", systemImage: "arrow.up.arrow.down") {
            Picker("Sort", selection: $sortOrder) {
                Text("By Spending").tag(CategoryChartSortOrder.bySpending)
                Text("By Category").tag(CategoryChartSortOrder.byCategoryOrder)
            }
            .pickerStyle(.inline)
        }
        .labelStyle(.iconOnly)
        .font(.caption)
        .textCase(nil)
    }
}
