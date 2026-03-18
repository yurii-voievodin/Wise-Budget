import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expenseFilter: ExpenseFilter

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?

    private var monthTitle: String {
        expenseFilter.startOfMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        ExpenseQueryListView(
            filter: expenseFilter,
            expenseToEdit: $expenseToEdit
        )
        .id(expenseFilter)
        .navigationTitle(monthTitle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            ToolbarItem {
                Menu {
                    Button {
                        expenseFilter.foreignOnly = false
                    } label: {
                        if !expenseFilter.foreignOnly {
                            Label("None", systemImage: "checkmark")
                        } else {
                            Text("None")
                        }
                    }
                    Button {
                        expenseFilter.foreignOnly = true
                    } label: {
                        if expenseFilter.foreignOnly {
                            Label("Foreign currency", systemImage: "checkmark")
                        } else {
                            Text("Foreign currency")
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle\(expenseFilter.foreignOnly ? ".fill" : "")")
                }
            }
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

    private func moveMonth(by delta: Int) {
        expenseFilter = expenseFilter.moved(by: delta)
    }
}



