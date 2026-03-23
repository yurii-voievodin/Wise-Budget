import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

@main
struct WiseBudgetApp: App {
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
            // If the store is corrupted, fall back to in-memory so the app can still launch
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @FocusedValue(\.resetBudgetPlan) private var resetBudgetPlan

    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var showingImportAlert = false
    @State private var showResetPlanConfirmation = false
    @State private var showingExportAlert = false
    @State private var exportError: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 750, maxWidth: 1400, minHeight: 400)
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    DataSeeder.prepopulateCategories(in: context)
                    DataSeeder.prepopulateIncomeCategories(in: context)
                    DataSeeder.migrateCategoryIcons(in: context)
                    BankSyncService.requestNotificationPermission()
                    disableFullScreen()
                }
                .alert("Reset Budget Plan", isPresented: $showResetPlanConfirmation) {
                    Button("Reset", role: .destructive) {
                        resetBudgetPlan?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will reset all planned amounts to zero and update the currency to the default. This action cannot be undone.")
                }
                .alert("Export", isPresented: $showingExportAlert) {
                    Button("OK") {}
                } message: {
                    if let error = exportError {
                        Text("Export failed: \(error)")
                    } else {
                        Text("Data exported successfully.")
                    }
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
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentSize)
        .modelContainer(sharedModelContainer)
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
        .commands {
            CommandGroup(replacing: .importExport) {
                Button("Export Data to CSV...") {
                    exportDataCSV()
                }
                Divider()
                Button("Import Data from CSV...") {
                    importAppDataCSV()
                }
                Divider()
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

    private func exportDataCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "WiseBudget-Export.csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let csvString = try CSVExporter.exportCSV(from: sharedModelContainer.mainContext)
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            exportError = nil
            showingExportAlert = true
        } catch {
            exportError = error.localizedDescription
            showingExportAlert = true
        }
    }

    private func importAppDataCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let rows = try AppDataCSVImporter.parseCSV(from: url)
            let context = sharedModelContainer.mainContext
            let result = try AppDataCSVImporter.importRows(rows, into: context)
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

    private func disableFullScreen() {
        for window in NSApplication.shared.windows {
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.insert(.fullScreenNone)
        }
    }

}
