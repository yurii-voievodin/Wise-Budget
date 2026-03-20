import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var isManagingCategories = false
    @State private var syncService = BankSyncService()

    enum ExpenseTab: Hashable {
        case expenses
        case chart
        case statistics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Expenses", systemImage: "list.bullet", value: .expenses) {
                ExpenseQueryListView(
                    filter: filter,
                    expenseToEdit: $expenseToEdit,
                    isAddingExpense: $isAddingExpense,
                    selectedSidebarItem: $selectedSidebarItem
                )
                .id(filter)
            }
            Tab("Statistics", systemImage: "tablecells", value: .statistics) {
                ExpenseStatisticsView(filter: filter)
                    .id(filter)
            }
            Tab("Chart", systemImage: "chart.pie", value: .chart) {
                ExpenseCategoryChartView(filter: filter)
                    .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            BankSyncToolbar(syncService: syncService, filter: filter)
            ToolbarItem {
                Button(action: { isManagingCategories = true }) {
                    Label("Manage Categories", systemImage: "tag")
                }
            }
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
        .sheet(isPresented: $isManagingCategories) {
            ExpenseCategoryManagementSheet()
        }
    }
}



