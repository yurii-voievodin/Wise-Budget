import SwiftUI

struct OnboardingBanksStep: View {
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @State private var showMonobankSheet = false
    @State private var showWiseSheet = false

    private var isMonobankConnected: Bool {
        !monobankConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
    }

    private var isWiseConnected: Bool {
        !wiseConnectedName.isEmpty
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    var body: some View {
        OnboardingStepLayout(
            icon: "creditcard.fill",
            iconColor: .pink,
            title: "Connect your banks",
            subtitle: "Import transactions automatically from Wise and Monobank. Tokens are stored in your macOS Keychain — never on a server. Both are optional."
        ) {
            VStack(spacing: 10) {
                BankConnectionRow(
                    title: "Monobank",
                    iconSystemName: "creditcard.fill",
                    iconColor: .pink,
                    isConnected: isMonobankConnected,
                    connectedName: monobankConnectedName,
                    lastSync: 0
                ) {
                    if !isMonobankConnected {
                        Button("Connect") { showMonobankSheet = true }
                            .controlSize(.small)
                    }
                }
                BankConnectionRow(
                    title: "Wise",
                    iconSystemName: "globe",
                    iconColor: .blue,
                    isConnected: isWiseConnected,
                    connectedName: wiseConnectedName,
                    lastSync: 0
                ) {
                    if !isWiseConnected {
                        Button("Connect") { showWiseSheet = true }
                            .controlSize(.small)
                    }
                }
            }
            .frame(maxWidth: 380)
        }
        .sheet(isPresented: $showMonobankSheet) {
            MonobankConnectSheet { name in
                monobankConnectedName = name
            }
        }
        .sheet(isPresented: $showWiseSheet) {
            WiseConnectSheet { name in
                wiseConnectedName = name
            }
        }
    }
}

#Preview {
    OnboardingBanksStep()
        .frame(width: 580, height: 460)
}
