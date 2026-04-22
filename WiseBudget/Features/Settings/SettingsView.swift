import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }

            Tab("Expense Categories", systemImage: "arrow.up.circle") {
                ExpenseCategorySettingsView()
            }

            Tab("Income Categories", systemImage: "arrow.down.circle") {
                IncomeCategorySettingsView()
            }
        }
        .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self], inMemory: true)
}
