import SwiftUI
import SwiftData

struct TransactionFormContent<C: CategoryModel & Hashable>: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let categories: [C]
    let entityLabel: String
    let extraFieldLabel: String
    let isEditing: Bool
    let accentColor: Color

    @Binding var amount: Decimal?
    @Binding var currency: String
    @Binding var date: Date
    @Binding var selectedCategory: C?
    @Binding var descriptionText: String
    @Binding var extraField: String
    @Binding var baseCurrencyAmount: Decimal?
    @Binding var isInternalTransfer: Bool

    var onSave: (TransactionFormPayload<C>) -> Void

    @FocusState private var isAmountFocused: Bool

    private var isForeignCurrency: Bool { currency != defaultCurrency }

    private var isSaveDisabled: Bool { (amount ?? .zero) <= .zero }

    private var tint: Color {
        guard let selectedCategory else { return accentColor }
        return C.badgeColor(for: selectedCategory.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            TransactionFormHeader(
                entityLabel: entityLabel,
                isEditing: isEditing,
                tint: tint,
                amount: $amount,
                currency: $currency,
                isAmountFocused: $isAmountFocused
            )
            TransactionFormFields(
                categories: categories,
                extraFieldLabel: extraFieldLabel,
                defaultCurrency: defaultCurrency,
                isForeignCurrency: isForeignCurrency,
                selectedCategory: $selectedCategory,
                date: $date,
                amount: $amount,
                currency: $currency,
                baseCurrencyAmount: $baseCurrencyAmount,
                descriptionText: $descriptionText,
                extraField: $extraField,
                isInternalTransfer: $isInternalTransfer
            )
            Divider()
            TransactionFormFooter(isEditing: isEditing, isSaveDisabled: isSaveDisabled, onSave: save)
        }
        .frame(minWidth: 460, idealWidth: 460)
        .defaultFocus($isAmountFocused, true)
        .onSubmit(save)
        .animation(Motion.standard, value: tint)
    }

    private func save() {
        guard let amount, amount > .zero else { return }
        let desc = descriptionText.trimmingCharacters(in: .whitespaces)
        let extra = extraField.trimmingCharacters(in: .whitespaces)
        onSave(TransactionFormPayload(
            amount: amount,
            currency: currency,
            date: date,
            category: selectedCategory,
            descriptionText: desc.isEmpty ? nil : desc,
            extraField: extra.isEmpty ? nil : extra,
            baseCurrencyAmount: isForeignCurrency ? baseCurrencyAmount : nil,
            baseCurrency: isForeignCurrency ? defaultCurrency : nil,
            isInternalTransfer: isInternalTransfer
        ))
        dismiss()
    }
}
