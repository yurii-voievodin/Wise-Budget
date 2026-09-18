import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback
    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0
    @AppStorage("monobankSyncedUpTo") private var monobankSyncedUpTo: Double = 0
    @AppStorage("wiseSyncedUpTo") private var wiseSyncedUpTo: Double = 0
    @AppStorage(SpendingInsightsService.userPreferenceKey) private var aiInsightsEnabled: Bool = SpendingInsightsService.userPreferenceDefault

    @State private var showDeleteAllExpensesConfirmation = false
    @State private var showDeleteAllIncomesConfirmation = false
    @State private var errorMessage: String?
    @State private var aiAvailability: SpendingInsightsService.Availability = .modelNotReady

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

            Section("AI Insights") {
                Toggle("Enable AI Insights", isOn: $aiInsightsEnabled)
                    .disabled(aiAvailability != .available)

                Label(Self.footerText(for: aiAvailability), systemImage: Self.footerIcon(for: aiAvailability))
                    .foregroundStyle(.secondary)
                    .font(.callout)
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
        .task {
            aiAvailability = SpendingInsightsService.currentAvailability()
            if aiAvailability != .available && aiInsightsEnabled {
                aiInsightsEnabled = false
            }
        }
    }

    private static func footerText(for availability: SpendingInsightsService.Availability) -> String {
        switch availability {
        case .available:
            return "Generate on-device narratives about your monthly spending and trends. Runs entirely on your Mac via Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in System Settings to enable AI insights."
        case .deviceNotEligible:
            return "This Mac doesn't support Apple Intelligence."
        case .modelNotReady:
            return "Apple Intelligence is preparing. Try again in a few minutes."
        case .other(let reason):
            return "Apple Intelligence unavailable: \(reason)"
        }
    }

    private static func footerIcon(for availability: SpendingInsightsService.Availability) -> String {
        availability == .available ? "sparkles" : "sparkles.slash"
    }

    private func deleteAllExpenses() {
        do {
            try modelContext.deleteAll(Expense.self)
            monobankLastSync = 0
            wiseLastSync = 0
            monobankSyncedUpTo = 0
            wiseSyncedUpTo = 0
        } catch {
            errorMessage = "Failed to delete expenses: \(error.localizedDescription)"
        }
    }

    private func deleteAllIncomes() {
        do {
            try modelContext.deleteAll(Income.self)
            monobankLastSync = 0
            wiseLastSync = 0
            monobankSyncedUpTo = 0
            wiseSyncedUpTo = 0
        } catch {
            errorMessage = "Failed to delete incomes: \(error.localizedDescription)"
        }
    }

}

#Preview {
    GeneralSettingsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
