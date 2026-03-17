import SwiftUI

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Decimal?
    @State private var currency: String
    @State private var date = Date()

    var onSave: (Decimal, String, Date) -> Void

    init(onSave: @escaping (Decimal, String, Date) -> Void) {
        self.onSave = onSave
        let defaultCurrency = Locale.current.currency?.identifier ?? "USD"
        _currency = State(initialValue: defaultCurrency)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .number)
                    .frame(width: 200)
                Picker("Currency", selection: $currency) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .padding(.horizontal)
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        onSave(amount, currency, date)
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
        }
        .frame(minWidth: 350, minHeight: 250)
    }
}

#Preview("Add Expense Sheet") {
    AddExpenseSheet { _, _, _ in }
}
