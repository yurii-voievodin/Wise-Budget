import SwiftUI
import SwiftData

struct ExpenseQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: ExpenseFilter
    @Binding var expenseToEdit: Expense?

    init(filter: ExpenseFilter, expenseToEdit: Binding<Expense?>) {
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

    /// Applies foreignOnly filtering in-memory (only when drilling down from budget plan)
    private var filteredExpenses: [Expense] {
        guard filter.foreignOnly, let planCurrency = filter.planCurrency else {
            return expenses
        }
        return expenses.filter { expense in
            if expense.currency == planCurrency { return false }
            if expense.baseCurrency == planCurrency && expense.baseCurrencyAmount != nil { return false }
            return true
        }
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
                                VStack(alignment: .trailing) {
                                    HStack(spacing: 4) {
                                        if expense.currency != defaultCurrency {
                                            Image(systemName: "globe")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        Text("\(expense.amount, format: .number) \(expense.currency)")
                                            .font(.headline)
                                    }
                                    if let baseAmount = expense.baseCurrencyAmount,
                                       let baseCur = expense.baseCurrency {
                                        Text("\(baseAmount, format: .number) \(baseCur)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
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
