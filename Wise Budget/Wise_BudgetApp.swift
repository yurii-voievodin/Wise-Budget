import SwiftUI
import SwiftData

@main
struct Wise_BudgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            Income.self,
            ExpenseCategory.self,
            IncomeCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    prepopulateCategories()
                    prepopulateIncomeCategories()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func prepopulateCategories() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaultNames = [
            "Auto", "Cafes", "Entertainment", "Groceries", "Home",
            "Medical", "Other", "Personal Items", "Taxes", "Travel", "Utilities"
        ]
        for name in defaultNames {
            context.insert(ExpenseCategory(name: name))
        }
    }

    private func prepopulateIncomeCategories() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<IncomeCategory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let defaultNames = [
            "Freelance", "Gifts", "Investments", "Other", "Rental", "Salary"
        ]
        for name in defaultNames {
            context.insert(IncomeCategory(name: name))
        }
    }
}
