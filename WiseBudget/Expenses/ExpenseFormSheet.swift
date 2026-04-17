import SwiftUI
import SwiftData

struct ExpenseFormSheet: View {
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date = Date.now
    @State private var selectedCategory: ExpenseCategory?
    @State private var descriptionText: String = ""
    @State private var destination: String = ""
    @State private var baseCurrencyAmount: Decimal?

    var expenseToEdit: Expense?
    var onSave: (Decimal, String, Date, ExpenseCategory?, String?, String?, Decimal?, String?) -> Void

    init(expense: Expense? = nil, onSave: @escaping (Decimal, String, Date, ExpenseCategory?, String?, String?, Decimal?, String?) -> Void) {
        self.expenseToEdit = expense
        self.onSave = onSave
        let storedCurrency = UserDefaults.standard.string(forKey: "defaultCurrency")
            ?? Locale.current.currency?.identifier ?? "USD"
        if let expense {
            _amount = State(initialValue: expense.amount)
            _currency = State(initialValue: expense.currency)
            _date = State(initialValue: expense.date)
            _selectedCategory = State(initialValue: expense.category)
            _descriptionText = State(initialValue: expense.descriptionText ?? "")
            _destination = State(initialValue: expense.destination ?? "")
            _baseCurrencyAmount = State(initialValue: expense.baseCurrencyAmount)
        } else {
            _currency = State(initialValue: storedCurrency)
        }
    }

    var body: some View {
        TransactionFormContent(
            categories: categories,
            entityLabel: "Expense",
            extraFieldLabel: "Destination",
            isEditing: expenseToEdit != nil,
            amount: $amount,
            currency: $currency,
            date: $date,
            selectedCategory: $selectedCategory,
            descriptionText: $descriptionText,
            extraField: $destination,
            baseCurrencyAmount: $baseCurrencyAmount,
            onSave: onSave
        )
    }
}

#Preview("Add Expense Sheet") {
    ExpenseFormSheet { _, _, _, _, _, _, _, _ in }
        .modelContainer(for: [ExpenseCategory.self, Expense.self], inMemory: true)
}
