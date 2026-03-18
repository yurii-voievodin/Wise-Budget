import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expenseFilter: ExpenseFilter?

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?

    private var filterTitle: String? {
        guard let filter = expenseFilter else { return nil }
        let comps = DateComponents(year: filter.year, month: filter.month, day: 1)
        guard let date = Calendar.current.date(from: comps) else { return nil }
        let monthLabel = date.formatted(.dateTime.month(.wide).year())
        if filter.foreignOnly {
            return "Foreign currency — \(monthLabel)"
        }
        return monthLabel
    }

    var body: some View {
        ExpenseQueryListView(
            filter: expenseFilter,
            expenseToEdit: $expenseToEdit
        )
        .id(expenseFilter)
        .navigationTitle("Expenses")
        .toolbar {
            if let filterTitle {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 4) {
                        Text(filterTitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button {
                            expenseFilter = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
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
}



