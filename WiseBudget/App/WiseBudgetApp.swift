import SwiftUI
import SwiftData
import TipKit
import UniformTypeIdentifiers

@main
struct WiseBudgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: WiseBudgetSchemaV1.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: WiseBudgetMigrationPlan.self,
                configurations: [modelConfiguration]
            )
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
    @FocusedValue(\.selectedMonthFilter) private var selectedMonthFilter

    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var showingImportAlert = false
    @State private var showResetPlanConfirmation = false
    @State private var showingExportAlert = false
    @State private var exportError: String?
    @State private var localAIAppDetector = LocalAIAppDetector()
    @State private var backfillRunning = false
    @State private var backfillResult: BaseCurrencyBackfillService.Result?
    @State private var backfillError: String?
    @State private var showingBackfillAlert = false
    @State private var showOnboarding = false

    @AppStorage(OnboardingFlowView.completedKey) private var hasCompletedOnboarding: Bool = false

    init() {
        try? Tips.configure([.displayFrequency(.monthly), .datastoreLocation(.applicationDefault)])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 750, maxWidth: 1600, minHeight: 400)
                .environment(localAIAppDetector)
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    DataSeeder.prepopulateCategories(in: context)
                    DataSeeder.prepopulateIncomeCategories(in: context)
                    DataSeeder.migrateCategoryIcons(in: context)
                    DataSeeder.prepopulateSubscriptionCategory(in: context)
                    DataSeeder.prepopulateGiftsCategory(in: context)
                    DataSeeder.prepopulateImportCategories(in: context)
                    Task { await BankSyncService.requestNotificationPermission() }
                    disableFullScreen()
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingFlowView()
                        .environment(localAIAppDetector)
                }
                .reviewPrompt()
                .alert("Delete Budget Plan", isPresented: $showResetPlanConfirmation) {
                    Button("Delete", role: .destructive) {
                        resetBudgetPlan?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will delete the budget plan for the selected month. This action cannot be undone.")
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
                .alert("Backfill Base Currency", isPresented: $showingBackfillAlert) {
                    Button("OK") {}
                } message: {
                    if let error = backfillError {
                        Text("Backfill failed: \(error)")
                    } else if let r = backfillResult {
                        let perCurrency = r.perCurrencyConverted
                            .sorted(by: { $0.value > $1.value })
                            .map { "\($0.key): \($0.value)" }
                            .joined(separator: ", ")
                        Text("""
                        Converted \(r.convertedCount) transactions — \(r.convertedExpenses) expenses, \(r.convertedIncomes) incomes (\(r.ratesFetched) rates fetched).
                        Already had base: \(r.alreadyHadBase). Same currency: \(r.sameCurrency). Failed: \(r.failedRateFetches).
                        \(perCurrency.isEmpty ? "" : "By currency — \(perCurrency).")
                        """)
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
        .defaultSize(width: 1100, height: 700)
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
                Button("Export Selected Month to CSV...") {
                    exportSelectedMonthCSV()
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
                Divider()
                Button("Backfill Base Currency for Selected Month...") {
                    backfillSelectedMonthBaseCurrency()
                }
                .disabled(backfillRunning)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Reset Budget Plan...") {
                    showResetPlanConfirmation = true
                }
                .disabled(resetBudgetPlan == nil)
            }
            CommandGroup(replacing: .help) {
                Button("Show Onboarding") {
                    showOnboarding = true
                }
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

    private func exportSelectedMonthCSV() {
        let filter = selectedMonthFilter ?? .currentMonth()
        let dateRange = DateInterval(start: filter.startOfMonth, end: filter.startOfNextMonth)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let monthLabel = formatter.string(from: dateRange.start)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "WiseBudget-\(monthLabel).csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let csvString = try CSVExporter.exportCSV(
                from: sharedModelContainer.mainContext,
                dateRange: dateRange
            )
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

    private func backfillSelectedMonthBaseCurrency() {
        let filter = selectedMonthFilter ?? .currentMonth()
        let dateRange = DateInterval(start: filter.startOfMonth, end: filter.startOfNextMonth)
        let baseCurrency = DefaultCurrency.resolve()
        let context = sharedModelContainer.mainContext

        backfillRunning = true
        Task { @MainActor in
            defer { backfillRunning = false }
            do {
                let result = try await BaseCurrencyBackfillService.backfill(
                    in: dateRange,
                    baseCurrency: baseCurrency,
                    context: context
                )
                backfillResult = result
                backfillError = nil
            } catch {
                backfillResult = nil
                backfillError = error.localizedDescription
            }
            showingBackfillAlert = true
        }
    }

    private func disableFullScreen() {
        for window in NSApplication.shared.windows {
            window.collectionBehavior.remove(.fullScreenPrimary)
            window.collectionBehavior.insert(.fullScreenNone)
        }
    }

}
