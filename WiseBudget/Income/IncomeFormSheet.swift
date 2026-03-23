import SwiftUI
import SwiftData

struct IncomeFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date = Date()
    @State private var selectedCategory: IncomeCategory?
    @State private var descriptionText: String = ""
    @State private var source: String = ""
    @State private var baseCurrencyAmount: Decimal?

    var incomeToEdit: Income?
    var onSave: (Decimal, String, Date, IncomeCategory?, String?, String?, Decimal?, String?) -> Void

    private var isEditing: Bool { incomeToEdit != nil }
    private var isForeignCurrency: Bool { currency != defaultCurrency }

    init(income: Income? = nil, onSave: @escaping (Decimal, String, Date, IncomeCategory?, String?, String?, Decimal?, String?) -> Void) {
        self.incomeToEdit = income
        self.onSave = onSave
        let storedCurrency = UserDefaults.standard.string(forKey: "defaultCurrency")
            ?? Locale.current.currency?.identifier ?? "USD"
        if let income {
            _amount = State(initialValue: income.amount)
            _currency = State(initialValue: income.currency)
            _date = State(initialValue: income.date)
            _selectedCategory = State(initialValue: income.category)
            _descriptionText = State(initialValue: income.descriptionText ?? "")
            _source = State(initialValue: income.source ?? "")
            _baseCurrencyAmount = State(initialValue: income.baseCurrencyAmount)
        } else {
            _currency = State(initialValue: storedCurrency)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .number)
                    .frame(width: 200)
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(IncomeCategory?.none)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.displayIconName).tag(IncomeCategory?.some(category))
                    }
                }
                Picker("Currency", selection: $currency) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
                if isForeignCurrency {
                    BaseCurrencyField(
                        baseCurrencyAmount: $baseCurrencyAmount,
                        amount: amount,
                        currency: currency,
                        defaultCurrency: defaultCurrency,
                        date: date
                    )
                }
                TextField("Description", text: $descriptionText)
                TextField("Source", text: $source)
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .padding(.horizontal)
            .navigationTitle(isEditing ? "Edit Income" : "Add Income")
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
                        let src = source.trimmingCharacters(in: .whitespaces)
                        let baseAmount = isForeignCurrency ? baseCurrencyAmount : nil
                        let baseCur = isForeignCurrency ? defaultCurrency : nil
                        onSave(amount, currency, date, selectedCategory, desc.isEmpty ? nil : desc, src.isEmpty ? nil : src, baseAmount, baseCur)
                        dismiss()
                    }
                    .disabled(amount == nil || (amount ?? .zero) <= .zero)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}

#Preview("Add Income Sheet") {
    IncomeFormSheet { _, _, _, _, _, _, _, _ in }
        .modelContainer(for: [IncomeCategory.self, Income.self], inMemory: true)
}
