import SwiftUI
import SwiftData

struct ExpenseDayDetailView: View {
    @Query private var expenses: [Expense]

    let date: Date

    @State private var expenseToEdit: Expense?

    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startOfDay && expense.date < endOfDay && !expense.isInternalTransfer
            },
            sort: \.date
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small) {
            Text(date, format: Date.FormatStyle(date: .long))
                .font(.headline)
                .padding(.bottom, Layout.Spacing.tight)

            ForEach(expenses) { expense in
                Button {
                    expenseToEdit = expense
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let desc = expense.descriptionText {
                                Text(desc)
                                    .font(.body)
                            }
                            if let category = expense.category {
                                Label(category.name, systemImage: category.displayIconName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        CurrencyAmountView(item: expense)
                    }
                    .padding(.vertical, Layout.Spacing.tight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 350)
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(expense: expense) { result in
                withAnimation { result.apply(to: expense) }
            }
        }
    }
}

#Preview {
    ExpenseDayDetailView(date: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 17))!)
        .modelContainer(PreviewSampleData.container)
}
