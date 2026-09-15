import SwiftUI
import SwiftData

struct ExpenseFormSheet: View {
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date: Date
    @State private var selectedCategory: ExpenseCategory?
    @State private var descriptionText: String = ""
    @State private var destination: String = ""
    @State private var baseCurrencyAmount: Decimal?
    @State private var isInternalTransfer: Bool = false

    var expenseToEdit: Expense?
    var onSave: (ExpenseFormResult) -> Void

    init(expense: Expense? = nil, initialDate: Date = .now, onSave: @escaping (ExpenseFormResult) -> Void) {
        self.expenseToEdit = expense
        self.onSave = onSave
        let storedCurrency = DefaultCurrency.resolve()
        if let expense {
            _amount = State(initialValue: expense.amount)
            _currency = State(initialValue: expense.currency)
            _date = State(initialValue: expense.date)
            _selectedCategory = State(initialValue: expense.category)
            _descriptionText = State(initialValue: expense.descriptionText ?? "")
            _destination = State(initialValue: expense.destination ?? "")
            _baseCurrencyAmount = State(initialValue: expense.baseCurrencyAmount)
            _isInternalTransfer = State(initialValue: expense.isInternalTransfer)
        } else {
            _currency = State(initialValue: storedCurrency)
            _date = State(initialValue: initialDate)
        }
    }

    var body: some View {
        TransactionFormContent(
            categories: categories,
            entityLabel: "Expense",
            extraFieldLabel: "Destination",
            isEditing: expenseToEdit != nil,
            accentColor: .expense,
            amount: $amount,
            currency: $currency,
            date: $date,
            selectedCategory: $selectedCategory,
            descriptionText: $descriptionText,
            extraField: $destination,
            baseCurrencyAmount: $baseCurrencyAmount,
            isInternalTransfer: $isInternalTransfer
        ) { payload in
            onSave(ExpenseFormResult(
                amount: payload.amount,
                currency: payload.currency,
                date: payload.date,
                category: payload.category,
                descriptionText: payload.descriptionText,
                destination: payload.extraField,
                baseCurrencyAmount: payload.baseCurrencyAmount,
                baseCurrency: payload.baseCurrency,
                isInternalTransfer: payload.isInternalTransfer
            ))
        }
    }
}

#Preview("Add Expense Sheet") {
    ExpenseFormSheet { _ in }
        .modelContainer(for: [ExpenseCategory.self, Expense.self], inMemory: true)
}
