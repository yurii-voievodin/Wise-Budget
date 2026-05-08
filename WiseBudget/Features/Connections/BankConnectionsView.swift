import SwiftUI
import SwiftData

struct BankConnectionsView: View {
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

    private var isMonobankConnected: Bool {
        !monobankConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
    }

    private var isWiseConnected: Bool {
        !wiseConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

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
                        Button("Connect") { showConnectSheet = true }
                            .buttonStyle(.borderedProminent)
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
                        Button("Connect") { showWiseConnectSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .formStyle(.grouped)

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

    private func disconnectMonobank() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.monobankService)
        monobankConnectedName = ""
        monobankLastSync = 0
        UserDefaults.standard.removeObject(forKey: "monobankAccountDetails")
        UserDefaults.standard.removeObject(forKey: "monobankSelectedAccounts")
    }

    private func disconnectWise() {
        try? KeychainHelper.deleteToken(service: KeychainHelper.wiseService)
        wiseConnectedName = ""
        wiseLastSync = 0
    }
}

#Preview {
    BankConnectionsView()
        .modelContainer(for: [Expense.self, Income.self], inMemory: true)
}
