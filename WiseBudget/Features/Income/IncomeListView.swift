import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var selectedTab: IncomeTab
    @Bindable var syncService: BankSyncService

    @Query(sort: \IncomeCategory.name) private var incomeCategories: [IncomeCategory]

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var selectedCategoryName: String?
    @State private var searchText: String = ""
    @State private var isSearchPresented: Bool = false

    enum IncomeTab: Hashable {
        case incomes
        case table
    }

    var body: some View {
        tabContent
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .toolbar,
                prompt: "Search incomes"
            )
    }

    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .incomes:
                IncomeQueryListView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    incomeToEdit: $incomeToEdit,
                    isAddingIncome: $isAddingIncome,
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService
                )
                .id(filter)
            case .table:
                IncomeTableView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    searchText: searchText,
                    incomeToEdit: $incomeToEdit
                )
                .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ToolbarItem {
                Picker("Section", selection: $selectedTab) {
                    Label("Incomes", systemImage: "list.bullet").tag(IncomeTab.incomes)
                    Label("Table", systemImage: "tablecells").tag(IncomeTab.table)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            CategoryFilterToolbar(
                selectedCategoryName: $selectedCategoryName,
                categories: incomeCategories.map { ($0.name, $0.displayIconName) }
            )
            ToolbarItem {
                Button(action: { isAddingIncome = true }) {
                    Label("Add Income", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingIncome) {
            IncomeFormSheet { result in
                withAnimation {
                    modelContext.insert(result.makeIncome())
                }
            }
        }
        .sheet(item: $incomeToEdit) { income in
            IncomeFormSheet(income: income) { result in
                withAnimation { result.apply(to: income) }
            }
        }
    }
}

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    @Previewable @State var selectedSidebarItem: SidebarItem = .income
    @Previewable @State var selectedTab: IncomeListView.IncomeTab = .incomes
    IncomeListView(filter: $filter, selectedSidebarItem: $selectedSidebarItem, selectedTab: $selectedTab, syncService: BankSyncService())
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 500)
}
