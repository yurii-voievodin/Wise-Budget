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

    private var groupedExpenses: [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value) }
    }

    var body: some View {
        Group {
            if !hasAnyExpenses && !syncService.hasBankToken {
                emptyStateView
            } else if filteredExpenses.isEmpty {
                monthEmptyStateView
            } else {
                List {
                    ForEach(groupedExpenses, id: \.date) { group in
                        Section {
                            ForEach(group.expenses) { expense in
                                Button {
                                    expenseToEdit = expense
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            if let desc = expense.descriptionText {
                                                Text(desc)
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                            }
                                            if let category = expense.category {
                                                Label(category.name, systemImage: category.displayIconName)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            if let dest = expense.destination {
                                                Text(dest)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                        Spacer()
                                        CurrencyAmountView(item: expense)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                deleteExpenses(from: group.expenses, at: offsets)
                            }
                        } header: {
                            HStack {
                                Text(group.date, format: Date.FormatStyle(date: .long))
                                Spacer()
                                Text(dayTotal(for: group.expenses), format: .number)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { checkHasAnyExpenses() }
        .onChange(of: expenses.count) { checkHasAnyExpenses() }
    }

    private func checkHasAnyExpenses() {
        let descriptor = FetchDescriptor<Expense>()
        hasAnyExpenses = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private var monthEmptyStateView: some View {
        MonthEmptyStateView(
            title: "No Expenses This Month",
            systemImage: "creditcard",
            filter: filter,
            syncService: syncService
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Expenses Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add your first expense, import from a CSV file,\nor connect a bank account to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    isAddingExpense = true
                } label: {
                    Label("Add Expense", systemImage: "plus")
                }

                Button {
                    selectedSidebarItem = .bankConnections
                } label: {
                    Label("Connect Bank", systemImage: "link")
                }
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayTotal(for expenses: [Expense]) -> Decimal {
        expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func deleteExpenses(from groupExpenses: [Expense], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groupExpenses[index])
            }
        }
    }
}
