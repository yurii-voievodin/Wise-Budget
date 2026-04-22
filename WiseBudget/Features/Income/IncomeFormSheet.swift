import SwiftUI
import SwiftData

struct IncomeFormSheet: View {
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date = Date.now
    @State private var selectedCategory: IncomeCategory?
    @State private var descriptionText: String = ""
    @State private var source: String = ""
    @State private var baseCurrencyAmount: Decimal?

    var incomeToEdit: Income?
    var onSave: (Decimal, String, Date, IncomeCategory?, String?, String?, Decimal?, String?) -> Void

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
        TransactionFormContent(
            categories: categories,
            entityLabel: "Income",
            extraFieldLabel: "Source",
            isEditing: incomeToEdit != nil,
            amount: $amount,
            currency: $currency,
            date: $date,
            selectedCategory: $selectedCategory,
            descriptionText: $descriptionText,
            extraField: $source,
            baseCurrencyAmount: $baseCurrencyAmount,
            onSave: onSave
        )
    }
}

#Preview("Add Income Sheet") {
    IncomeFormSheet { _, _, _, _, _, _, _, _ in }
        .modelContainer(for: [IncomeCategory.self, Income.self], inMemory: true)
}
