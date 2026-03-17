import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    var body: some View {
        List {
            ForEach(expenses) { expense in
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.amount, format: .number)
                            .font(.headline)
                        Text(expense.date, format: Date.FormatStyle(date: .numeric, time: .standard))
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
                Button(action: addExpense) {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
    }

    private func addExpense() {
        withAnimation {
            let newExpense = Expense(amount: 0, currency: Locale.current.currency?.identifier ?? "USD")
            modelContext.insert(newExpense)
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
