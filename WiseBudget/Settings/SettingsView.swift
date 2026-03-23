import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ExpenseCategorySettingsView()
                .tabItem {
                    Label("Expense Categories", systemImage: "arrow.up.circle")
                }

            IncomeCategorySettingsView()
                .tabItem {
                    Label("Income Categories", systemImage: "arrow.down.circle")
                }
        }
        .frame(width: 500, height: 350)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Expense.self, Income.self, ExpenseCategory.self, IncomeCategory.self], inMemory: true)
}
