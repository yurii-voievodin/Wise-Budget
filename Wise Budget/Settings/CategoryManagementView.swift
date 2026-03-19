import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var expenseCategories: [ExpenseCategory]
    @Query(sort: \IncomeCategory.name) private var incomeCategories: [IncomeCategory]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"
    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @State private var newExpenseCategoryName = ""
    @State private var newIncomeCategoryName = ""
    @State private var showDeleteAllExpensesConfirmation = false
    @State private var showDeleteAllIncomesConfirmation = false
    @State private var showConnectSheet = false
    @State private var showAccountsSheet = false
    @State private var showDisconnectConfirmation = false
    @State private var isSyncing = false
    @State private var syncResultMessage: String?
    @State private var showSyncAlert = false

    @State private var showWiseConnectSheet = false
    @State private var showWiseDisconnectConfirmation = false
    @State private var isWiseSyncing = false
    @State private var wiseSyncResultMessage: String?
    @State private var showWiseSyncAlert = false

    private var isMonobankConnected: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
    }

    private var isWiseConnected: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    var body: some View {
        List {
            Section("Bank Connections") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monobank")
                            .fontWeight(.medium)
                        if isMonobankConnected {
                            Text("Connected as \(monobankConnectedName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if isMonobankConnected {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Sync Now") {
                                syncMonobank()
                            }
                        }

                        Button("Accounts") {
                            showAccountsSheet = true
                        }

                        Button("Disconnect", role: .destructive) {
                            showDisconnectConfirmation = true
                        }
                    } else {
                        Button("Connect") {
                            showConnectSheet = true
                        }
                    }
                }

                if isMonobankConnected && monobankLastSync > 0 {
                    Text("Last sync: \(Date(timeIntervalSince1970: monobankLastSync), style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wise")
                            .fontWeight(.medium)
                        if isWiseConnected {
                            Text("Connected as \(wiseConnectedName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if isWiseConnected {
                        if isWiseSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Button("Sync Now") {
                                syncWise()
                            }
                        }

                        Button("Disconnect", role: .destructive) {
                            showWiseDisconnectConfirmation = true
                        }
                    } else {
                        Button("Connect") {
                            showWiseConnectSheet = true
                        }
                    }
                }

                if isWiseConnected && wiseLastSync > 0 {
                    Text("Last sync: \(Date(timeIntervalSince1970: wiseLastSync), style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

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
        .sheet(isPresented: $showConnectSheet) {
            MonobankConnectSheet { name in
                monobankConnectedName = name
            }
        }
        .sheet(isPresented: $showAccountsSheet) {
            MonobankAccountsSheet()
        }
        .confirmationDialog(
            "Disconnect Monobank",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                disconnectMonobank()
            }
        } message: {
            Text("This will remove your Monobank token. Previously imported transactions will not be deleted.")
        }
        .alert("Monobank Sync", isPresented: $showSyncAlert) {
            Button("OK") {}
        } message: {
            Text(syncResultMessage ?? "")
        }
        .sheet(isPresented: $showWiseConnectSheet) {
            WiseConnectSheet { name in
                wiseConnectedName = name
            }
        }
        .confirmationDialog(
            "Disconnect Wise",
            isPresented: $showWiseDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                disconnectWise()
            }
        } message: {
            Text("This will remove your Wise token. Previously imported transactions will not be deleted.")
        }
        .alert("Wise Sync", isPresented: $showWiseSyncAlert) {
            Button("OK") {}
        } message: {
            Text(wiseSyncResultMessage ?? "")
        }
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

    private func syncMonobank() {
        isSyncing = true
        Task {
            do {
                let result = try await MonobankSyncService.sync(
                    context: modelContext,
                    lastSyncTimestamp: monobankLastSync > 0 ? monobankLastSync : nil
                )
                await MainActor.run {
                    monobankLastSync = Date().timeIntervalSince1970
                    isSyncing = false
                    if result.expensesImported == 0 && result.incomesImported == 0 {
                        syncResultMessage = "Already up to date. \(result.duplicatesSkipped) duplicates skipped."
                    } else {
                        syncResultMessage = "\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.duplicatesSkipped) duplicates skipped."
                    }
                    showSyncAlert = true
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncResultMessage = error.localizedDescription
                    showSyncAlert = true
                }
            }
        }
    }

    private func disconnectMonobank() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.monobankService)
        monobankConnectedName = ""
        monobankLastSync = 0
    }

    private func syncWise() {
        isWiseSyncing = true
        Task {
            do {
                let result = try await WiseSyncService.sync(
                    context: modelContext,
                    lastSyncTimestamp: wiseLastSync > 0 ? wiseLastSync : nil
                )
                await MainActor.run {
                    wiseLastSync = Date().timeIntervalSince1970
                    isWiseSyncing = false
                    if result.expensesImported == 0 && result.incomesImported == 0 {
                        wiseSyncResultMessage = "Already up to date. \(result.duplicatesSkipped) duplicates skipped."
                    } else {
                        wiseSyncResultMessage = "\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.duplicatesSkipped) duplicates skipped."
                    }
                    showWiseSyncAlert = true
                }
            } catch {
                await MainActor.run {
                    isWiseSyncing = false
                    wiseSyncResultMessage = error.localizedDescription
                    showWiseSyncAlert = true
                }
            }
        }
    }

    private func disconnectWise() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.wiseService)
        wiseConnectedName = ""
        wiseLastSync = 0
    }
}

#Preview {
    CategoryManagementView()
        .modelContainer(for: [ExpenseCategory.self, IncomeCategory.self, Expense.self, Income.self], inMemory: true)
}
