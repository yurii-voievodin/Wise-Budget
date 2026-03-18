import SwiftUI
import SwiftData

struct ExpenseQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    @Binding var expenseToEdit: Expense?

    init(filter: MonthFilter, expenseToEdit: Binding<Expense?>) {
        self.filter = filter
        self._expenseToEdit = expenseToEdit

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var filteredExpenses: [Expense] {
        guard filter.foreignOnly else { return expenses }
        return expenses.filterForeignCurrency(defaultCurrency: defaultCurrency)
    }

    private var groupedExpenses: [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value) }
    }

    var body: some View {
        List {
            ForEach(groupedExpenses, id: \.date) { group in
                Section {
                    ForEach(group.expenses) { expense in
                        Button {
                            expenseToEdit = expense
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let desc = expense.descriptionText {
                                        Text(desc)
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                    if let categoryName = expense.category?.name {
                                        Text(categoryName)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    if let dest = expense.destination {
                                        Text(dest)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                CurrencyAmountView(item: expense)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteExpenses(from: group.expenses, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(group.date, format: Date.FormatStyle(date: .long))
                        Spacer()
                        Text(dayTotal(for: group.expenses), format: .number)
                    }
                }
            }
        }
    }

    private func dayTotal(for expenses: [Expense]) -> Decimal {
        expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func deleteExpenses(from groupExpenses: [Expense], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groupExpenses[index])
            }
        }
    }
}
