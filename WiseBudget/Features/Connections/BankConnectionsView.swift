import SwiftUI
import SwiftData

struct BankConnectionsView: View {
    let syncService: BankSyncService

    @Environment(\.modelContext) private var modelContext

    @AppStorage("monobankLastSync") private var monobankLastSync: Double = 0
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseLastSync") private var wiseLastSync: Double = 0
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @State private var showConnectSheet = false
    @State private var showAccountsSheet = false
    @State private var showDisconnectConfirmation = false

    @State private var showWiseConnectSheet = false
    @State private var showWiseDisconnectConfirmation = false

    @State private var isMonobankConnected = false
    @State private var isWiseConnected = false

    var body: some View {
        Form {
            Section {
                Text("Connect Monobank or Wise to import transactions automatically. Tokens are stored in your macOS Keychain — never on a server.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                BankConnectionRow(
                    title: "Monobank",
                    iconSystemName: "creditcard.fill",
                    iconColor: .pink,
                    isConnected: isMonobankConnected,
                    connectedName: monobankConnectedName,
                    lastSync: monobankLastSync
                ) {
                    if isMonobankConnected {
                        Button("Accounts") { showAccountsSheet = true }
                        Button("Disconnect", role: .destructive) {
                            showDisconnectConfirmation = true
                        }
                    } else {
                        disconnectedActions(
                            connectedName: monobankConnectedName,
                            onConnect: { showConnectSheet = true },
                            onForget: disconnectMonobank
                        )
                    }
                }
            }

            Section {
                BankConnectionRow(
                    title: "Wise",
                    iconSystemName: "globe",
                    iconColor: .blue,
                    isConnected: isWiseConnected,
                    connectedName: wiseConnectedName,
                    lastSync: wiseLastSync
                ) {
                    if isWiseConnected {
                        Button("Disconnect", role: .destructive) {
                            showWiseDisconnectConfirmation = true
                        }
                    } else {
                        disconnectedActions(
                            connectedName: wiseConnectedName,
                            onConnect: { showWiseConnectSheet = true },
                            onForget: disconnectWise
                        )
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            refreshConnectionState()
        }
        .sheet(isPresented: $showConnectSheet) {
            MonobankConnectSheet { name in
                monobankConnectedName = name
                syncService.refreshConnectionStatus()
                refreshConnectionState()
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
                syncService.refreshConnectionStatus()
                refreshConnectionState()
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
        .navigationTitle("")
    }

    @ViewBuilder
    private func disconnectedActions(
        connectedName: String,
        onConnect: @escaping () -> Void,
        onForget: @escaping () -> Void
    ) -> some View {
        if !connectedName.isEmpty {
            Button("Forget", role: .destructive, action: onForget)
            Button("Reconnect", action: onConnect)
                .buttonStyle(.borderedProminent)
        } else {
            Button("Connect", action: onConnect)
                .buttonStyle(.borderedProminent)
        }
    }

    private func disconnectMonobank() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.monobankService)
        monobankConnectedName = ""
        monobankLastSync = 0
        UserDefaults.standard.removeObject(forKey: "monobankAccountDetails")
        UserDefaults.standard.removeObject(forKey: "monobankSelectedAccounts")
        syncService.refreshConnectionStatus()
        refreshConnectionState()
    }

    private func disconnectWise() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.wiseService)
        wiseConnectedName = ""
        wiseLastSync = 0
        syncService.refreshConnectionStatus()
        refreshConnectionState()
    }

    private func refreshConnectionState() {
        isMonobankConnected = KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
        isWiseConnected = KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }
}

#Preview {
    BankConnectionsView(syncService: BankSyncService())
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
