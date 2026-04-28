import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0

    @State private var showDeleteAllExpensesConfirmation = false
    @State private var showDeleteAllIncomesConfirmation = false
    @State private var errorMessage: String?

    private static let currencyOptions: [(code: String, label: String)] = Locale.commonISOCurrencyCodes.map { code in
        let localized = Locale.current.localizedString(forCurrencyCode: code) ?? code
        return (code, "\(code) – \(localized)")
    }

    var body: some View {
        List {
            Section("General") {
                Picker("Default Currency", selection: $defaultCurrency) {
                    ForEach(Self.currencyOptions, id: \.code) { option in
                        Text(option.label).tag(option.code)
                    }
                }
            }

            Section("Data Management") {
                Button(role: .destructive) {
                    showDeleteAllExpensesConfirmation = true
                } label: {
                    Label("Delete All Expenses", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Delete All Expenses",
                    isPresented: $showDeleteAllExpensesConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Expenses", role: .destructive, action: deleteAllExpenses)
                } message: {
                    Text("This will permanently delete all your expenses. This action cannot be undone.")
                }

                Button(role: .destructive) {
                    showDeleteAllIncomesConfirmation = true
                } label: {
                    Label("Delete All Incomes", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                .confirmationDialog(
                    "Delete All Incomes",
                    isPresented: $showDeleteAllIncomesConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Incomes", role: .destructive, action: deleteAllIncomes)
                } message: {
                    Text("This will permanently delete all your incomes. This action cannot be undone.")
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            presenting: errorMessage
        ) { _ in
            Button("OK") { errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    private func deleteAllExpenses() {
        do {
            try modelContext.deleteAll(Expense.self)
            monobankLastSync = 0
            wiseLastSync = 0
        } catch {
            errorMessage = "Failed to delete expenses: \(error.localizedDescription)"
        }
    }

    private func deleteAllIncomes() {
        do {
            try modelContext.deleteAll(Income.self)
            monobankLastSync = 0
            wiseLastSync = 0
        } catch {
            errorMessage = "Failed to delete incomes: \(error.localizedDescription)"
        }
    }

}

#Preview {
    GeneralSettingsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
