import SwiftUI

struct SidebarList: View {
    @Binding var selectedSidebarItem: SidebarItem
    var syncService: BankSyncService
    let monthFilter: MonthFilter

    private static let overviewItems: [SidebarItem] = [
        .dashboard, .budgetPlan, .expenses, .income, .cashflow, .lifetime
    ]

    var body: some View {
        List(selection: $selectedSidebarItem) {
            Section("Overview") {
                ForEach(Self.overviewItems, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarBottomSection(
                selectedSidebarItem: $selectedSidebarItem,
                syncService: syncService,
                monthFilter: monthFilter
            )
        }
    }
}
