import SwiftUI
import SwiftData

struct ExpenseFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var amount: Decimal?
    @State private var currency: String = ""
    @State private var date = Date()
    @State private var selectedCategory: ExpenseCategory?
    @State private var descriptionText: String = ""
    @State private var destination: String = ""
    @State private var baseCurrencyAmount: Decimal?

    var expenseToEdit: Expense?
    var onSave: (Decimal, String, Date, ExpenseCategory?, String?, String?, Decimal?, String?) -> Void

    private var isEditing: Bool { expenseToEdit != nil }
    private var isForeignCurrency: Bool { currency != defaultCurrency }

    init(expense: Expense? = nil, onSave: @escaping (Decimal, String, Date, ExpenseCategory?, String?, String?, Decimal?, String?) -> Void) {
        self.expenseToEdit = expense
        self.onSave = onSave
        if let expense {
            _amount = State(initialValue: expense.amount)
            _currency = State(initialValue: expense.currency)
            _date = State(initialValue: expense.date)
            _selectedCategory = State(initialValue: expense.category)
            _descriptionText = State(initialValue: expense.descriptionText ?? "")
            _destination = State(initialValue: expense.destination ?? "")
            _baseCurrencyAmount = State(initialValue: expense.baseCurrencyAmount)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .number)
                    .frame(width: 200)
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(ExpenseCategory?.none)
                    ForEach(categories) { category in
                        Text(category.name).tag(ExpenseCategory?.some(category))
                    }
                }
                Picker("Currency", selection: $currency) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
                if isForeignCurrency {
                    TextField("Amount in \(defaultCurrency)", value: $baseCurrencyAmount, format: .number)
                        .frame(width: 200)
                }
                TextField("Description", text: $descriptionText)
                TextField("Destination", text: $destination)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .padding(.horizontal)
            .navigationTitle(isEditing ? "Edit Expense" : "Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        let desc = descriptionText.trimmingCharacters(in: .whitespaces)
                        let dest = destination.trimmingCharacters(in: .whitespaces)
                        let baseAmount = isForeignCurrency ? baseCurrencyAmount : nil
                        let baseCur = isForeignCurrency ? defaultCurrency : nil
                        onSave(amount, currency, date, selectedCategory, desc.isEmpty ? nil : desc, dest.isEmpty ? nil : dest, baseAmount, baseCur)
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
        .onAppear {
            if currency.isEmpty {
                currency = defaultCurrency
            }
        }
    }
}

#Preview("Add Expense Sheet") {
    ExpenseFormSheet { _, _, _, _, _, _, _, _ in }
        .modelContainer(for: [ExpenseCategory.self, Expense.self], inMemory: true)
}
