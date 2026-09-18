import SwiftUI

struct TransactionFormFields<C: CategoryModel & Hashable>: View {
    let categories: [C]
    let extraFieldLabel: String
    let defaultCurrency: String
    let isForeignCurrency: Bool

    @Binding var selectedCategory: C?
    @Binding var date: Date
    @Binding var amount: Decimal?
    @Binding var currency: String
    @Binding var baseCurrencyAmount: Decimal?
    @Binding var descriptionText: String
    @Binding var extraField: String
    @Binding var isInternalTransfer: Bool

    var body: some View {
        VStack(spacing: Layout.Spacing.medium) {
            FormCard {
                FormRow(label: "Category") {
                    TransactionCategoryMenu(categories: categories, selectedCategory: $selectedCategory)
                }
                FormRowDivider()
                FormRow(label: "Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                if isForeignCurrency {
                    FormRowDivider()
                    FormRow(label: "In \(defaultCurrency)") {
                        BaseCurrencyField(
                            baseCurrencyAmount: $baseCurrencyAmount,
                            amount: amount,
                            currency: currency,
                            defaultCurrency: defaultCurrency,
                            date: date
                        )
                    }
                }
            }
            FormCard {
                FormRow(label: "Description") {
                    TextField("Optional", text: $descriptionText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Description")
                }
                FormRowDivider()
                FormRow(label: extraFieldLabel) {
                    TextField("Optional", text: $extraField)
                        .textFieldStyle(.plain)
                        .accessibilityLabel(extraFieldLabel)
                }
            }
            FormCard {
                TransactionTransferRow(isInternalTransfer: $isInternalTransfer)
            }
        }
        .padding(Layout.Spacing.xLarge)
    }
}
