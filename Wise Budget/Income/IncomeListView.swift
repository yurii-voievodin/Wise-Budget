import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?

    var body: some View {
        List {
            ForEach(incomes) { income in
                Button {
                    incomeToEdit = income
                } label: {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
        .sheet(item: $incomeToEdit) { income in
            AddIncomeSheet(income: income) { amount, currency, date, category in
                withAnimation {
                    income.amount = amount
                    income.currency = currency
                    income.date = date
                    income.category = category
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
