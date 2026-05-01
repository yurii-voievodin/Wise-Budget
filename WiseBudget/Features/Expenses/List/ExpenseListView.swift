import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var selectedCategoryName: String?
    @Binding var selectedTab: ExpenseTab

    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var syncService = BankSyncService()

    enum ExpenseTab: Hashable {
        case expenses
        case calendar
        case comparison
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                ExpenseCalendarView(filter: filter, syncService: syncService)
                    .id(filter)
            }
            Tab("Expenses", systemImage: "list.bullet", value: .expenses) {
                ExpenseQueryListView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    expenseToEdit: $expenseToEdit,
                    isAddingExpense: $isAddingExpense,
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService
                )
                .id(filter)
            }
            Tab("Comparison", systemImage: "chart.bar.xaxis", value: .comparison) {
                ExpenseComparisonView(filter: filter)
                    .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            if selectedTab == .expenses {
                ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
                CategoryFilterToolbar(
                    selectedCategoryName: $selectedCategoryName,
                    categories: expenseCategories.map { ($0.name, $0.displayIconName) }
                )
                ToolbarItem {
                    Button(action: { isAddingExpense = true }) {
                        Label("Add Expense", systemImage: "plus")
                    }
                }
            }
            BankSyncToolbar(syncService: syncService, filter: filter)
        }
        .sheet(isPresented: $isAddingExpense) {
            ExpenseFormSheet { result in
                withAnimation {
                    modelContext.insert(result.makeExpense())
                }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(expense: expense) { result in
                withAnimation { result.apply(to: expense) }
            }
        }
    }
}

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    @Previewable @State var selectedSidebarItem: SidebarItem = .expenses
    @Previewable @State var selectedCategoryName: String? = nil
    @Previewable @State var selectedTab: ExpenseListView.ExpenseTab = .calendar
    ExpenseListView(filter: $filter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $selectedCategoryName, selectedTab: $selectedTab)
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 500)
}
