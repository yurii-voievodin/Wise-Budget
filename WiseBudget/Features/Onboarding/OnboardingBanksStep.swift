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
                connectRow(
                    title: "Monobank",
                    icon: "creditcard.fill",
                    iconColor: .pink,
                    isConnected: isMonobankConnected,
                    name: monobankConnectedName,
                    action: { showMonobankSheet = true }
                )
                connectRow(
                    title: "Wise",
                    icon: "globe",
                    iconColor: .blue,
                    isConnected: isWiseConnected,
                    name: wiseConnectedName,
                    action: { showWiseSheet = true }
                )
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

    @ViewBuilder
    private func connectRow(title: String, icon: String, iconColor: Color, isConnected: Bool, name: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(.medium)
                if isConnected, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button("Connect", action: action)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

#Preview {
    OnboardingBanksStep()
        .frame(width: 580, height: 460)
}
