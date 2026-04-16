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
        !monobankConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
    }

    private var isWiseConnected: Bool {
        !wiseConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    var body: some View {
        List {
            Section("Monobank") {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isMonobankConnected ? .green : Color.secondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isMonobankConnected ? "Connected" : "Not connected")
                                .fontWeight(.medium)
                            if isMonobankConnected {
                                Text(monobankConnectedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if isMonobankConnected && monobankLastSync > 0 {
                    Label {
                        Text("Last sync: \(Date(timeIntervalSince1970: monobankLastSync), style: .relative) ago")
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Section("Wise") {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isWiseConnected ? .green : Color.secondary.opacity(0.3))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isWiseConnected ? "Connected" : "Not connected")
                                .fontWeight(.medium)
                            if isWiseConnected {
                                Text(wiseConnectedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if isWiseConnected && wiseLastSync > 0 {
                    Label {
                        Text("Last sync: \(Date(timeIntervalSince1970: wiseLastSync), style: .relative) ago")
                    } icon: {
                        Image(systemName: "clock")
                    }
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
        guard !isSyncing else { return }
        isSyncing = true
        Task {
            defer { isSyncing = false }
            do {
                let fromTs: Double
                if monobankLastSync > 0 {
                    fromTs = monobankLastSync
                } else {
                    let comps = Calendar.current.dateComponents([.year, .month], from: Date.now)
                    fromTs = (Calendar.current.date(from: comps) ?? Date.now).timeIntervalSince1970
                }
                let result = try await MonobankSyncService.sync(
                    context: modelContext,
                    fromTimestamp: fromTs,
                    toTimestamp: Date.now.timeIntervalSince1970
                )
                monobankLastSync = Date.now.timeIntervalSince1970
                if result.expensesImported == 0 && result.incomesImported == 0 {
                    syncResultMessage = "Already up to date. \(result.duplicatesSkipped) duplicates skipped."
                } else {
                    syncResultMessage = "\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.duplicatesSkipped) duplicates skipped."
                }
                postNotification(title: "Monobank Sync", message: syncResultMessage)
            } catch {
                syncResultMessage = error.localizedDescription
                postNotification(title: "Monobank Sync", message: syncResultMessage)
            }
        }
    }

    private func disconnectMonobank() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.monobankService)
        monobankConnectedName = ""
        monobankLastSync = 0
        UserDefaults.standard.removeObject(forKey: "monobankAccountDetails")
        UserDefaults.standard.removeObject(forKey: "monobankSelectedAccounts")
    }

    private func syncWise() {
        guard !isWiseSyncing else { return }
        isWiseSyncing = true
        Task {
            defer { isWiseSyncing = false }
            do {
                let wiseFromTs: Double
                if wiseLastSync > 0 {
                    wiseFromTs = wiseLastSync
                } else {
                    let comps = Calendar.current.dateComponents([.year, .month], from: Date.now)
                    wiseFromTs = (Calendar.current.date(from: comps) ?? Date.now).timeIntervalSince1970
                }
                let result = try await WiseSyncService.sync(
                    context: modelContext,
                    fromTimestamp: wiseFromTs,
                    toTimestamp: Date.now.timeIntervalSince1970
                )
                wiseLastSync = Date.now.timeIntervalSince1970
                if result.expensesImported == 0 && result.incomesImported == 0 {
                    wiseSyncResultMessage = "Already up to date. \(result.duplicatesSkipped) duplicates skipped."
                } else {
                    wiseSyncResultMessage = "\(result.expensesImported) expenses, \(result.incomesImported) incomes imported. \(result.duplicatesSkipped) duplicates skipped."
                }
                postNotification(title: "Wise Sync", message: wiseSyncResultMessage)
            } catch {
                wiseSyncResultMessage = error.localizedDescription
                postNotification(title: "Wise Sync", message: wiseSyncResultMessage)
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
