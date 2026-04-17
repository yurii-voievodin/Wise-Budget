import SwiftUI
import SwiftData

struct ExpenseQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @State private var hasAnyExpenses = true

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    let selectedCategoryName: String?
    @Binding var expenseToEdit: Expense?
    @Binding var isAddingExpense: Bool
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, selectedCategoryName: String?, expenseToEdit: Binding<Expense?>, isAddingExpense: Binding<Bool>, selectedSidebarItem: Binding<SidebarItem>, syncService: BankSyncService) {
        self.filter = filter
        self.selectedCategoryName = selectedCategoryName
        self._expenseToEdit = expenseToEdit
        self._isAddingExpense = isAddingExpense
        self._selectedSidebarItem = selectedSidebarItem
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
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
        if let categoryName = selectedCategoryName {
            result = result.filter { $0.category?.name == categoryName }
        }
        return result
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
            extraField: { $0.destination },
            onSelect: { expenseToEdit = $0 },
            onAdd: { isAddingExpense = true },
            onNavigateToBank: { selectedSidebarItem = .bankConnections }
        )
        .onAppear { checkHasAnyExpenses() }
        .onChange(of: expenses.count) { checkHasAnyExpenses() }
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
