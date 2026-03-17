import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var isAddingExpense = false

    var body: some View {
        List {
            ForEach(expenses) { expense in
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.amount, format: .number)
                            .font(.headline)
                        if let categoryName = expense.category?.name {
                            Text(categoryName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(expense.date, format: Date.FormatStyle(date: .numeric))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(expense.currency)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteExpenses)
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem {
                Button(action: { isAddingExpense = true }) {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingExpense) {
            AddExpenseSheet { amount, currency, date, category in
                withAnimation {
                    let newExpense = Expense(amount: amount, currency: currency, date: date, category: category)
                    modelContext.insert(newExpense)
                }
            }
        }
    }

    private func deleteExpenses(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(expenses[index])
            }
        }
    }
}


