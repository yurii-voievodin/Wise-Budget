import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    var body: some View {
        List {
            ForEach(incomes) { income in
                HStack {
                    VStack(alignment: .leading) {
                        Text(income.amount, format: .number)
                            .font(.headline)
                        Text(income.date, format: Date.FormatStyle(date: .numeric, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(income.currency)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteIncomes)
        }
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem {
                Button(action: addIncome) {
                    Label("Add Income", systemImage: "plus")
                }
            }
        }
    }

    private func addIncome() {
        withAnimation {
            let newIncome = Income(amount: 0, currency: Locale.current.currency?.identifier ?? "USD")
            modelContext.insert(newIncome)
        }
    }

    private func deleteIncomes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(incomes[index])
            }
        }
    }
}
