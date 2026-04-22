import SwiftUI

struct DashboardEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Data This Month", systemImage: "square.grid.2x2")
                .foregroundStyle(.secondary)
        } description: {
            Text("Add expenses or income to see your monthly overview.")
        }
    }
}

#Preview {
    DashboardEmptyStateView()
}
