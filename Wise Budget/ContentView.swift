import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .expenses

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
            case .expenses:
                ExpenseListView()
            case .income:
                IncomeListView()
            case .settings:
                CategoryManagementView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self], inMemory: true)
}
