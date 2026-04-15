import SwiftUI
import SwiftData

struct IncomeQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @State private var hasAnyIncomes = true

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    let selectedCategoryName: String?
    @Binding var incomeToEdit: Income?
    @Binding var isAddingIncome: Bool
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService

    init(filter: MonthFilter, selectedCategoryName: String?, incomeToEdit: Binding<Income?>, isAddingIncome: Binding<Bool>, selectedSidebarItem: Binding<SidebarItem>, syncService: BankSyncService) {
        self.filter = filter
        self.selectedCategoryName = selectedCategoryName
        self._incomeToEdit = incomeToEdit
        self._isAddingIncome = isAddingIncome
        self._selectedSidebarItem = selectedSidebarItem
        self.syncService = syncService

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var filteredIncomes: [Income] {
        var result = incomes
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
            groups: groupByDate(filteredIncomes, dateKeyPath: \.date),
            hasAnyItems: hasAnyIncomes,
            hasBankToken: false,
            filter: filter,
            syncService: syncService,
            emptyTitle: "No Income Yet",
            emptyIcon: "creditcard",
            monthEmptyTitle: "No Income This Month",
            monthEmptyIcon: "banknote",
            addLabel: "Add Income",
            descriptionText: { $0.descriptionText },
            categoryName: { $0.category?.name },
            categoryIcon: { $0.category?.displayIconName },
            extraField: { $0.source },
            onSelect: { incomeToEdit = $0 },
            onAdd: { isAddingIncome = true },
            onNavigateToBank: { selectedSidebarItem = .bankConnections }
        )
        .onAppear { checkHasAnyIncomes() }
        .onChange(of: incomes.count) { checkHasAnyIncomes() }
    }

    private func checkHasAnyIncomes() {
        let descriptor = FetchDescriptor<Income>()
        hasAnyIncomes = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }
}

#Preview {
    @Previewable @State var incomeToEdit: Income? = nil
    @Previewable @State var isAddingIncome = false
    @Previewable @State var selectedSidebarItem: SidebarItem = .income
    IncomeQueryListView(
        filter: MonthFilter(year: 2026, month: 3),
        selectedCategoryName: nil,
        incomeToEdit: $incomeToEdit,
        isAddingIncome: $isAddingIncome,
        selectedSidebarItem: $selectedSidebarItem,
        syncService: BankSyncService()
    )
    .modelContainer(PreviewSampleData.container)
    .frame(width: 600, height: 400)
}
