import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

@main
struct Wise_BudgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            Income.self,
            ExpenseCategory.self,
            IncomeCategory.self,
            BudgetPlan.self,
            BudgetPlanItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @FocusedValue(\.resetBudgetPlan) private var resetBudgetPlan

    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var showingImportAlert = false
    @State private var showResetPlanConfirmation = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    prepopulateCategories()
                    prepopulateIncomeCategories()
                }
                .alert("Reset Budget Plan", isPresented: $showResetPlanConfirmation) {
                    Button("Reset", role: .destructive) {
                        resetBudgetPlan?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will reset all planned amounts to zero and update the currency to the default. This action cannot be undone.")
                }
                .alert("Import Complete", isPresented: $showingImportAlert) {
                    Button("OK") {}
                } message: {
                    if let error = importError {
                        Text("Import failed: \(error)")
                    } else if let result = importResult {
                        if result.duplicatesSkipped > 0 {
                            Text("\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.skipped) skipped. \(result.duplicatesSkipped) duplicates skipped.")
                        } else {
                            Text("\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.skipped) skipped.")
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Import from WISE CSV...") {
                    importCSV()
                }
                Button("Import from Monobank CSV...") {
                    importMonobankCSV()
                }
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Reset Budget Plan...") {
                    showResetPlanConfirmation = true
                }
                .disabled(resetBudgetPlan == nil)
            }
        }
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let transactions = try CSVImporter.parseCSV(from: url)
            let context = sharedModelContainer.mainContext
            let result = try CSVImporter.importTransactions(transactions, into: context)
            try context.save()
            importResult = result
            importError = nil
            showingImportAlert = true
        } catch {
            importResult = nil
            importError = error.localizedDescription
            showingImportAlert = true
        }
    }

    private func importMonobankCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let transactions = try MonobankCSVImporter.parseCSV(from: url)
            let context = sharedModelContainer.mainContext
            let result = try MonobankCSVImporter.importTransactions(transactions, into: context)
            try context.save()
            importResult = result
            importError = nil
            showingImportAlert = true
        } catch {
            importResult = nil
            importError = error.localizedDescription
            showingImportAlert = true
        }
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
