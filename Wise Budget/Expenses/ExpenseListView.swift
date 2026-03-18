import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var filter: MonthFilter

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?

    var body: some View {
        ExpenseQueryListView(
            filter: filter,
            expenseToEdit: $expenseToEdit
        )
        .id(filter)
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            ToolbarItem {
                Button(action: { isAddingExpense = true }) {
                    Label("Add Expense", systemImage: "plus")
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
    }

}



