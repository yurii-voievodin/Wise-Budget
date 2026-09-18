import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var selectedCategoryName: String?
    @Binding var selectedTab: ExpenseTab
    @Bindable var syncService: BankSyncService

    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false

    enum ExpenseTab: Hashable {
        case expenses
        case calendar
        case table
    }

    private var supportsSearch: Bool {
        selectedTab == .expenses || selectedTab == .table
    }

    private var supportsListFilters: Bool {
        selectedTab == .expenses || selectedTab == .table
    }

    @ViewBuilder
    var body: some View {
        if supportsSearch {
            tabContent
                .searchable(
                    text: $searchText,
                    isPresented: $isSearchPresented,
                    placement: .toolbar,
                    prompt: "Search expenses"
                )
        } else {
            tabContent
                .onAppear(perform: resetSearch)
        }
    }

    private func resetSearch() {
        isSearchPresented = false
        searchText = ""
    }

    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .calendar:
                ExpenseCalendarView(filter: filter, syncService: syncService)
                    .id(MonthKey(year: filter.year, month: filter.month))
            case .expenses:
                ExpenseQueryListView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    searchText: searchText,
                    expenseToEdit: $expenseToEdit,
                    isAddingExpense: $isAddingExpense,
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService
                )
                .id(MonthKey(year: filter.year, month: filter.month))
            case .table:
                ExpenseTableView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    searchText: searchText,
                    expenseToEdit: $expenseToEdit
                )
                .id(MonthKey(year: filter.year, month: filter.month))
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ToolbarItem {
                Picker("Section", selection: $selectedTab) {
                    Label("Calendar", systemImage: "calendar").tag(ExpenseTab.calendar)
                    Label("Expenses", systemImage: "list.bullet").tag(ExpenseTab.expenses)
                    Label("Table", systemImage: "tablecells").tag(ExpenseTab.table)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if supportsListFilters {
                TransactionFilterToolbar(foreignOnly: $filter.foreignOnly, sourceFilter: $filter.sourceFilter)
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
        }
        .sheet(isPresented: $isAddingExpense) {
            ExpenseFormSheet(initialDate: filter.startOfMonth) { result in
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
    ExpenseListView(filter: $filter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $selectedCategoryName, selectedTab: $selectedTab, syncService: BankSyncService())
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 500)
}
