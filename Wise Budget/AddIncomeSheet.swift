import SwiftUI
import SwiftData

struct AddIncomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var amount: Decimal?
    @State private var currency: String = ""
    @State private var date = Date()
    @State private var selectedCategory: IncomeCategory?

    var onSave: (Decimal, String, Date, IncomeCategory?) -> Void

    init(onSave: @escaping (Decimal, String, Date, IncomeCategory?) -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", value: $amount, format: .number)
                    .frame(width: 200)
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(IncomeCategory?.none)
                    ForEach(categories) { category in
                        Text(category.name).tag(IncomeCategory?.some(category))
                    }
                }
                Picker("Currency", selection: $currency) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
                DatePicker("Date", selection: $date, displayedComponents: .date)
            }
            .padding(.horizontal)
            .navigationTitle("Add Income")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        onSave(amount, currency, date, selectedCategory)
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

#Preview("Add Income Sheet") {
    AddIncomeSheet { _, _, _, _ in }
        .modelContainer(for: [IncomeCategory.self, Income.self], inMemory: true)
}
