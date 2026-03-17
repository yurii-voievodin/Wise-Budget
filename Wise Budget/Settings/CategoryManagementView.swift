import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]
    @Query(sort: \IncomeCategory.name) private var incomeCategories: [IncomeCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    @State private var newExpenseCategoryName = ""
    @State private var newIncomeCategoryName = ""

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

            Section("Expense Categories") {
                ForEach(expenseCategories) { category in
                    @Bindable var category = category
                    TextField("Category name", text: $category.name)
                }
                .onDelete(perform: deleteExpenseCategory)

                HStack {
                    TextField("New category", text: $newExpenseCategoryName)
                    Button("Add") {
                        addExpenseCategory()
                    }
                    .disabled(newExpenseCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Income Categories") {
                ForEach(incomeCategories) { category in
                    @Bindable var category = category
                    TextField("Category name", text: $category.name)
                }
                .onDelete(perform: deleteIncomeCategory)

                HStack {
                    TextField("New category", text: $newIncomeCategoryName)
                    Button("Add") {
                        addIncomeCategory()
                    }
                    .disabled(newIncomeCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func addExpenseCategory() {
        let name = newExpenseCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(ExpenseCategory(name: name))
        newExpenseCategoryName = ""
    }

    private func deleteExpenseCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenseCategories[index])
        }
    }

    private func addIncomeCategory() {
        let name = newIncomeCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(IncomeCategory(name: name))
        newIncomeCategoryName = ""
    }

    private func deleteIncomeCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(incomeCategories[index])
        }
    }
}

#Preview {
    CategoryManagementView()
        .modelContainer(for: [ExpenseCategory.self, IncomeCategory.self, Expense.self, Income.self], inMemory: true)
}
