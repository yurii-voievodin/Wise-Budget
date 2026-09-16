import SwiftUI
import SwiftData

struct ExpenseQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @State private var hasAnyExpenses = true

    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    let selectedCategoryName: String?
    let searchText: String
    @Binding var expenseToEdit: Expense?
    @Binding var isAddingExpense: Bool
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, selectedCategoryName: String?, searchText: String = "", expenseToEdit: Binding<Expense?>, isAddingExpense: Binding<Bool>, selectedSidebarItem: Binding<SidebarItem>, syncService: BankSyncService) {
        self.filter = filter
        self.selectedCategoryName = selectedCategoryName
        self.searchText = searchText
        self._expenseToEdit = expenseToEdit
        self._isAddingExpense = isAddingExpense
        self._selectedSidebarItem = selectedSidebarItem
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth
        let categoryName = selectedCategoryName

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate &&
                (categoryName == nil || expense.category?.name == categoryName)
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var filteredExpenses: [Expense] {
        var result = expenses
        if filter.foreignOnly {
            result = result.filterForeignCurrency(defaultCurrency: defaultCurrency)
        }
        result = result.filterBySource(filter.sourceFilter)
        return result.filterBySearchText(
            searchText,
            descriptionText: { $0.descriptionText },
            categoryName: { $0.category?.name },
            extraField: { $0.destination }
        )
    }

    var body: some View {
        TransactionListContent(
            groups: groupByDate(filteredExpenses, dateKeyPath: \.date),
            hasAnyItems: hasAnyExpenses,
            hasBankToken: syncService.hasBankToken,
            filter: filter,
            syncService: syncService,
            emptyTitle: "No Expenses Yet",
            emptyIcon: "creditcard",
            monthEmptyTitle: "No Expenses This Month",
            monthEmptyIcon: "creditcard",
            addLabel: "Add Expense",
            descriptionText: { $0.descriptionText },
            categoryName: { $0.category?.name },
            categoryIcon: { $0.category?.displayIconName },
            categoryColor: { $0.category.map { DefaultExpenseCategory.color(for: $0.name) } },
            extraField: { $0.destination },
            onSelect: { expenseToEdit = $0 },
            onAdd: { isAddingExpense = true },
            onNavigateToBank: { selectedSidebarItem = .bankConnections }
        )
        .task(id: expenses.count) { checkHasAnyExpenses() }
    }

    private func checkHasAnyExpenses() {
        let descriptor = FetchDescriptor<Expense>()
        hasAnyExpenses = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}

#Preview {
    @Previewable @State var expenseToEdit: Expense? = nil
    @Previewable @State var isAddingExpense = false
    @Previewable @State var selectedSidebarItem: SidebarItem = .expenses
    ExpenseQueryListView(
        filter: MonthFilter(year: 2026, month: 3),
        selectedCategoryName: nil,
        expenseToEdit: $expenseToEdit,
        isAddingExpense: $isAddingExpense,
        selectedSidebarItem: $selectedSidebarItem,
        syncService: BankSyncService()
    )
    .modelContainer(PreviewSampleData.container)
    .frame(width: 600, height: 400)
}
