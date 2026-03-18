import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expenseFilter: ExpenseFilter?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?

    private var filteredExpenses: [Expense] {
        guard let filter = expenseFilter else { return expenses }
        let calendar = Calendar.current
        return expenses.filter { expense in
            let comps = calendar.dateComponents([.year, .month], from: expense.date)
            guard comps.year == filter.year && comps.month == filter.month else { return false }
            if filter.foreignOnly, let planCurrency = filter.planCurrency {
                // Show only expenses that can't be converted to the plan currency
                if expense.currency == planCurrency { return false }
                if expense.baseCurrency == planCurrency && expense.baseCurrencyAmount != nil { return false }
                return true
            }
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
        .navigationTitle("Expenses")
        .toolbar {
            if let filterTitle {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 4) {
                        Text(filterTitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button {
                            clearFilter()
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

    private func dayTotal(for expenses: [Expense]) -> Decimal {
        expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func clearFilter() {
        expenseFilter = nil
    }

    private func deleteExpenses(from groupExpenses: [Expense], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groupExpenses[index])
            }
        }
    }
}


