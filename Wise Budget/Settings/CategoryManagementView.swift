import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0

    @State private var showDeleteAllExpensesConfirmation = false
    @State private var showDeleteAllIncomesConfirmation = false

    var body: some View {
        List {
            Section("General") {
                Picker("Default Currency", selection: $defaultCurrency) {
                    ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                        Text("\(code) – \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
                            .tag(code)
                    }
                }
            }

            Section("Data Management") {
                Button("Delete All Expenses", role: .destructive) {
                    showDeleteAllExpensesConfirmation = true
                }
                .confirmationDialog(
                    "Delete All Expenses",
                    isPresented: $showDeleteAllExpensesConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Expenses", role: .destructive) {
                        deleteAllExpenses()
                    }
                } message: {
                    Text("This will permanently delete all your expenses. This action cannot be undone.")
                }

                Button("Delete All Incomes", role: .destructive) {
                    showDeleteAllIncomesConfirmation = true
                }
                .confirmationDialog(
                    "Delete All Incomes",
                    isPresented: $showDeleteAllIncomesConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete All Incomes", role: .destructive) {
                        deleteAllIncomes()
                    }
                } message: {
                    Text("This will permanently delete all your incomes. This action cannot be undone.")
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func deleteAllExpenses() {
        do {
            let expenses = try modelContext.fetch(FetchDescriptor<Expense>())
            for expense in expenses {
                modelContext.delete(expense)
            }
            monobankLastSync = 0
            wiseLastSync = 0
        } catch {
            print("Failed to delete expenses: \(error)")
        }
    }

    private func deleteAllIncomes() {
        do {
            let incomes = try modelContext.fetch(FetchDescriptor<Income>())
            for income in incomes {
                modelContext.delete(income)
            }
            monobankLastSync = 0
            wiseLastSync = 0
        } catch {
            print("Failed to delete incomes: \(error)")
        }
    }


}

#Preview {
    CategoryManagementView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
