import SwiftUI
import SwiftData

struct TransactionFormContent<C: CategoryModel & Hashable>: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let categories: [C]
    let entityLabel: String
    let extraFieldLabel: String
    let isEditing: Bool

    @Binding var amount: Decimal?
    @Binding var currency: String
    @Binding var date: Date
    @Binding var selectedCategory: C?
    @Binding var descriptionText: String
    @Binding var extraField: String
    @Binding var baseCurrencyAmount: Decimal?
    @Binding var isInternalTransfer: Bool

    var onSave: (TransactionFormPayload<C>) -> Void

    private var isForeignCurrency: Bool { currency != defaultCurrency }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .number)
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(C?.none)
                    ForEach(categories) { category in
                        Label(category.name, systemImage: category.displayIconName).tag(C?.some(category))
                    }
                }
                NavigationLink {
                    CurrencyPickerScreen(currency: $currency)
                } label: {
                    LabeledContent("Currency") {
                        Text("\(currency) – \(Locale.current.localizedString(forCurrencyCode: currency) ?? currency)")
                            .foregroundStyle(.secondary)
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
                TextField(extraFieldLabel, text: $extraField)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Toggle("Transfer", isOn: $isInternalTransfer)
                    .help("Transfers between your own accounts stay in history but are excluded from statistics and budgets.")
            }
            .padding(.horizontal)
            .navigationTitle(isEditing ? "Edit \(entityLabel)" : "Add \(entityLabel)")
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
                        let extra = extraField.trimmingCharacters(in: .whitespaces)
                        let payload = TransactionFormPayload(
                            amount: amount,
                            currency: currency,
                            date: date,
                            category: selectedCategory,
                            descriptionText: desc.isEmpty ? nil : desc,
                            extraField: extra.isEmpty ? nil : extra,
                            baseCurrencyAmount: isForeignCurrency ? baseCurrencyAmount : nil,
                            baseCurrency: isForeignCurrency ? defaultCurrency : nil,
                            isInternalTransfer: isInternalTransfer
                        )
                        onSave(payload)
                        dismiss()
                    }
                    .disabled(amount == nil || (amount ?? .zero) <= .zero)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}
