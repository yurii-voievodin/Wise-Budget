import SwiftUI
import SwiftData
import UserNotifications

struct BankConnectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @State private var showConnectSheet = false
    @State private var showAccountsSheet = false
    @State private var showDisconnectConfirmation = false
    @State private var isSyncing = false
    @State private var syncResultMessage: String?

    @State private var showWiseConnectSheet = false
    @State private var showWiseDisconnectConfirmation = false
    @State private var isWiseSyncing = false
    @State private var wiseSyncResultMessage: String?

    private var isMonobankConnected: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
    }

    private var isWiseConnected: Bool {
        KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    var body: some View {
        List {
            Section("Monobank") {
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
            }

            Section("Wise") {
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
        }

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
    }

    // MARK: - Sync Methods

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
                    postNotification(title: "Monobank Sync", message: syncResultMessage)
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncResultMessage = error.localizedDescription
                    postNotification(title: "Monobank Sync", message: syncResultMessage)
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
                    postNotification(title: "Wise Sync", message: wiseSyncResultMessage)
                }
            } catch {
                await MainActor.run {
                    isWiseSyncing = false
                    wiseSyncResultMessage = error.localizedDescription
                    postNotification(title: "Wise Sync", message: wiseSyncResultMessage)
                }
            }
        }
    }

    private func disconnectWise() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.wiseService)
        wiseConnectedName = ""
        wiseLastSync = 0
    }

    private func postNotification(title: String, message: String?) {
        guard let message else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

#Preview {
    BankConnectionsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
