import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Income.date, order: .reverse) private var incomes: [Income]

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?

    private var groupedIncomes: [(date: Date, incomes: [Income])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: incomes) { income in
            calendar.startOfDay(for: income.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, incomes: $0.value) }
    }

    var body: some View {
        List {
            ForEach(groupedIncomes, id: \.date) { group in
                Section {
                    ForEach(group.incomes) { income in
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
                                    if let desc = income.descriptionText {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(income.currency)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteIncomes(from: group.incomes, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(group.date, format: Date.FormatStyle(date: .long))
                        Spacer()
                        Text(dayTotal(for: group.incomes), format: .number)
                    }
                }
            }
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
            AddIncomeSheet { amount, currency, date, category, descriptionText in
                withAnimation {
                    let newIncome = Income(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText)
                    modelContext.insert(newIncome)
                }
            }
        }
        .sheet(item: $incomeToEdit) { income in
            AddIncomeSheet(income: income) { amount, currency, date, category, descriptionText in
                withAnimation {
                    income.amount = amount
                    income.currency = currency
                    income.date = date
                    income.category = category
                    income.descriptionText = descriptionText
                }
            }
        }
    }

    private func dayTotal(for incomes: [Income]) -> Decimal {
        incomes.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func deleteIncomes(from groupIncomes: [Income], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groupIncomes[index])
            }
        }
    }
}
