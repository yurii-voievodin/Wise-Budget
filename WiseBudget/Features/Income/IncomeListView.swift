import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \IncomeCategory.name) private var incomeCategories: [IncomeCategory]

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var selectedTab: IncomeTab = .income
    @State private var selectedCategoryName: String?
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService

    enum IncomeTab: Hashable {
        case income
        case comparison
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .income:
                IncomeQueryListView(
                    filter: filter,
                    selectedCategoryName: selectedCategoryName,
                    incomeToEdit: $incomeToEdit,
                    isAddingIncome: $isAddingIncome,
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService
                )
                .id(filter)
            case .comparison:
                IncomeComparisonView(filter: filter) { month in
                    filter = filter.with(monthKey: month)
                    selectedTab = .income
                }
                .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ToolbarItem {
                Picker("Section", selection: $selectedTab) {
                    Label("Income", systemImage: "list.bullet").tag(IncomeTab.income)
                    Label("Comparison", systemImage: "chart.bar.xaxis").tag(IncomeTab.comparison)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            if selectedTab == .income {
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
    IncomeListView(filter: $filter, selectedSidebarItem: $selectedSidebarItem, syncService: BankSyncService())
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 500)
}
