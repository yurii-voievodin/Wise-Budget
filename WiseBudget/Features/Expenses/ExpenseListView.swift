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
    @State private var selectedTab: ExpenseTab = .calendar
    @State private var syncService = BankSyncService()

    enum ExpenseTab: Hashable {
        case expenses
        case calendar
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

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    @Previewable @State var selectedSidebarItem: SidebarItem = .expenses
    @Previewable @State var selectedCategoryName: String? = nil
    ExpenseListView(filter: $filter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $selectedCategoryName)
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 500)
}
