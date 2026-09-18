import SwiftUI

struct DashboardByCategoryButton: View {
    let expenseSlices: [CategoryChartSlice]
    let currency: String
    let onSelectCategory: (String) -> Void

    @State private var isPopoverPresented = false

    var body: some View {
        Button("By Category", systemImage: "chart.pie", action: togglePopover)
            .help("By Category")
            .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
                DashboardByCategoryTab(
                    expenseSlices: expenseSlices,
                    currency: currency,
                    onSelectCategory: selectCategory
                )
                .frame(minWidth: 420, minHeight: 480)
            }
    }

    private func togglePopover() {
        isPopoverPresented.toggle()
    }

    private func selectCategory(_ name: String) {
        isPopoverPresented = false
        onSelectCategory(name)
    }
}
