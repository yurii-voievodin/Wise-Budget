import SwiftUI
import SwiftData

struct IncomeFormSheet: View {
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date: Date
    @State private var selectedCategory: IncomeCategory?
    @State private var descriptionText: String = ""
    @State private var source: String = ""
    @State private var baseCurrencyAmount: Decimal?
    @State private var isInternalTransfer: Bool = false

    var incomeToEdit: Income?
    var onSave: (IncomeFormResult) -> Void

    init(income: Income? = nil, initialDate: Date = .now, onSave: @escaping (IncomeFormResult) -> Void) {
        self.incomeToEdit = income
        self.onSave = onSave
        let storedCurrency = DefaultCurrency.resolve()
        if let income {
            _amount = State(initialValue: income.amount)
            _currency = State(initialValue: income.currency)
            _date = State(initialValue: income.date)
            _selectedCategory = State(initialValue: income.category)
            _descriptionText = State(initialValue: income.descriptionText ?? "")
            _source = State(initialValue: income.source ?? "")
            _baseCurrencyAmount = State(initialValue: income.baseCurrencyAmount)
            _isInternalTransfer = State(initialValue: income.isInternalTransfer)
        } else {
            _currency = State(initialValue: storedCurrency)
            _date = State(initialValue: initialDate)
        }
    }

    var body: some View {
        TransactionFormContent(
            categories: categories,
            entityLabel: "Income",
            extraFieldLabel: "Source",
            isEditing: incomeToEdit != nil,
            accentColor: .income,
            amount: $amount,
            currency: $currency,
            date: $date,
            selectedCategory: $selectedCategory,
            descriptionText: $descriptionText,
            extraField: $source,
            baseCurrencyAmount: $baseCurrencyAmount,
            isInternalTransfer: $isInternalTransfer
        ) { payload in
            onSave(IncomeFormResult(
                amount: payload.amount,
                currency: payload.currency,
                date: payload.date,
                category: payload.category,
                descriptionText: payload.descriptionText,
                source: payload.extraField,
                baseCurrencyAmount: payload.baseCurrencyAmount,
                baseCurrency: payload.baseCurrency,
                isInternalTransfer: payload.isInternalTransfer
            ))
        }
    }
}

#Preview("Add Income Sheet") {
    IncomeFormSheet { _ in }
        .modelContainer(for: [IncomeCategory.self, Income.self], inMemory: true)
}
