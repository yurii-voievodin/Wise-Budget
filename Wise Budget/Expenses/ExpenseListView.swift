import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter

    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var selectedTab: ExpenseTab = .expenses
    @State private var isManagingCategories = false
    @State private var newCategoryName = ""

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
                    expenseToEdit: $expenseToEdit
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
            AddExpenseSheet { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    let newExpense = Expense(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText, destination: destination, baseCurrencyAmount: baseCurrencyAmount, baseCurrency: baseCurrency)
                    modelContext.insert(newExpense)
                }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            AddExpenseSheet(expense: expense) { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
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
            NavigationStack {
                List {
                    ForEach(expenseCategories) { category in
                        @Bindable var category = category
                        TextField("Category name", text: $category.name)
                    }
                    .onDelete(perform: deleteExpenseCategory)

                    HStack {
                        TextField("New category", text: $newCategoryName)
                        Button("Add") {
                            addExpenseCategory()
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .navigationTitle("Expense Categories")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isManagingCategories = false
                        }
                    }
                }
            }
            .frame(minWidth: 350, minHeight: 300)
        }
    }

    private func addExpenseCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(ExpenseCategory(name: name))
        newCategoryName = ""
    }

    private func deleteExpenseCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenseCategories[index])
        }
    }

}



