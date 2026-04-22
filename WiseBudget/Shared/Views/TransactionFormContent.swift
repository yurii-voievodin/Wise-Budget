import SwiftUI
import SwiftData

struct TransactionFormContent<C: CategoryModel & Hashable>: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

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

    var onSave: (Decimal, String, Date, C?, String?, String?, Decimal?, String?) -> Void

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
                        let baseAmount = isForeignCurrency ? baseCurrencyAmount : nil
                        let baseCur = isForeignCurrency ? defaultCurrency : nil
                        onSave(amount, currency, date, selectedCategory, desc.isEmpty ? nil : desc, extra.isEmpty ? nil : extra, baseAmount, baseCur)
                        dismiss()
                    }
                    .disabled(amount == nil || (amount ?? .zero) <= .zero)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}
