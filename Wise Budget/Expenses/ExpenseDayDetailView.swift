import SwiftUI

struct ExpenseDayDetailView: View {
    let expenses: [Expense]
    let date: Date

    @State private var expenseToEdit: Expense?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: Date.FormatStyle(date: .long))
                .font(.headline)
                .padding(.bottom, 4)

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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 350)
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(expense: expense) { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
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
}
