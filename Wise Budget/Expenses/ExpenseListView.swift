import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem
    @Binding var selectedCategoryName: String?

    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var syncService = BankSyncService()

    enum ExpenseTab: Hashable {
        case expenses
        case calendar
        case statistics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
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
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                ExpenseCalendarView(filter: filter, syncService: syncService)
                    .id(filter)
            }
            Tab("Statistics", systemImage: "chart.pie", value: .statistics) {
                ExpenseStatisticsView(filter: filter, syncService: syncService)
                    .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            CategoryFilterToolbar(
                selectedCategoryName: $selectedCategoryName,
                categories: expenseCategories.map { ($0.name, $0.displayIconName) }
            )
            BankSyncToolbar(syncService: syncService, filter: filter)
            if selectedTab == .expenses {
                ToolbarItem {
                    Button(action: { isAddingExpense = true }) {
                        Label("Add Expense", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingExpense) {
            ExpenseFormSheet { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    let newExpense = Expense(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText, destination: destination, baseCurrencyAmount: baseCurrencyAmount, baseCurrency: baseCurrency)
                    modelContext.insert(newExpense)
                }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(expense: expense) { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    expense.amount = amount
                    expense.currency = currency
                    expense.date = date
                    expense.category = category
                    expense.descriptionText = descriptionText
                    expense.destination = destination
                    expense.baseCurrencyAmount = baseCurrencyAmount
                    expense.baseCurrency = baseCurrency
                }
            }
        }
    }
}



