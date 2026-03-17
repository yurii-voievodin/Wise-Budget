import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    @State private var isAddingIncome = false

    var body: some View {
        List {
            ForEach(incomes) { income in
                HStack {
                    VStack(alignment: .leading) {
                        Text(income.amount, format: .number)
                            .font(.headline)
                        if let categoryName = income.category?.name {
                            Text(categoryName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(income.date, format: Date.FormatStyle(date: .numeric))
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
                Button(action: { isAddingIncome = true }) {
                    Label("Add Income", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingIncome) {
            AddIncomeSheet { amount, currency, date, category in
                withAnimation {
                    let newIncome = Income(amount: amount, currency: currency, date: date, category: category)
                    modelContext.insert(newIncome)
                }
            }
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
