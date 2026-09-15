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

    @State private var isCurrencyPickerPresented = false
    @FocusState private var isAmountFocused: Bool

    private var isForeignCurrency: Bool { currency != defaultCurrency }

    private var isSaveDisabled: Bool { (amount ?? .zero) <= .zero }

    private var tint: Color {
        guard let selectedCategory else { return accentColor }
        return C.badgeColor(for: selectedCategory.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            fields
            Divider()
            footer
        }
        .frame(width: 460)
        .defaultFocus($isAmountFocused, true)
        .onSubmit(save)
        .animation(.easeInOut(duration: 0.2), value: tint)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(isEditing ? "Edit \(entityLabel)" : "Add \(entityLabel)")
                .font(.headline)
                .foregroundStyle(.secondary)
            amountEditor
            Text(Locale.current.localizedString(forCurrencyCode: currency) ?? currency)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.16), tint.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var amountEditor: some View {
        HStack(spacing: 12) {
            TextField("0", value: $amount, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .focused($isAmountFocused)
                .frame(width: 180)
            currencyButton
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(isAmountFocused ? 0.6 : 0.2), lineWidth: 1)
        }
        .fixedSize()
    }

    private var currencyButton: some View {
        Button {
            isCurrencyPickerPresented = true
        } label: {
            HStack(spacing: 4) {
                Text(currency)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(tint.opacity(0.15), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Currency")
        .popover(isPresented: $isCurrencyPickerPresented, arrowEdge: .bottom) {
            CurrencyPickerScreen(currency: $currency)
                .frame(width: 300, height: 360)
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            card {
                FormRow(label: "Category") { categoryMenu }
                rowDivider
                FormRow(label: "Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }
                if isForeignCurrency {
                    rowDivider
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
            card {
                FormRow(label: "Description") {
                    TextField("Optional", text: $descriptionText)
                        .textFieldStyle(.plain)
                }
                rowDivider
                FormRow(label: extraFieldLabel) {
                    TextField("Optional", text: $extraField)
                        .textFieldStyle(.plain)
                }
            }
            card { transferRow }
        }
        .padding(20)
    }

    private var categoryMenu: some View {
        Menu {
            Button("None") { selectedCategory = nil }
            Divider()
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.name, systemImage: category.displayIconName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let selectedCategory {
                    CategoryIconBadge(
                        systemName: selectedCategory.displayIconName,
                        color: C.badgeColor(for: selectedCategory.name),
                        size: 22
                    )
                    Text(selectedCategory.name)
                } else {
                    CategoryIconBadge(systemName: "tray", color: .secondary, size: 22)
                    Text("None")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var transferRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Transfer between my accounts")
                Text("Kept in history, but excluded from statistics and budgets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isInternalTransfer)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Save" : "Add", action: save)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaveDisabled)
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var rowDivider: some View {
        Divider().opacity(0.6)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 12)
            .cardBackground(cornerRadius: 12)
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

private struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }
}
