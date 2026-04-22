import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "WiseConnect")

struct WiseConnectSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var connectedName: String?
    @State private var profiles: [WiseProfile] = []
    @State private var selectedProfile: WiseProfile?

    var onConnected: (String) -> Void

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Wise")
                .font(.headline)

            if let connectedName {
                WiseProfileSelectionView(
                    connectedName: connectedName,
                    profiles: profiles,
                    selectedProfile: $selectedProfile
                )
            } else {
                WiseTokenSetupView(token: $token)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Spacer()

            VStack(spacing: 8) {
                if connectedName != nil {
                    Button("Done", action: finishSelection)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Button(action: connectAccount) {
                        if isConnecting {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Connect account")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedToken.isEmpty || isConnecting)

                    Button("Cancel", action: dismiss.callAsFunction)
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }

                Text("Token is stored in your Keychain and never leaves your Mac")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 420, idealHeight: 500)
    }

    private func finishSelection() {
        saveSelections()
        dismiss()
    }

    private func saveSelections() {
        if let profile = selectedProfile {
            WiseSyncService.saveSelectedProfileId(profile.id)
        }
        logger.info("saved profile selection")
    }

    private func connectAccount() {
        let token = trimmedToken
        guard !token.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let client = WiseAPIClient(token: token)
                let fetchedProfiles = try await client.fetchProfiles()

                guard let firstProfile = fetchedProfiles.first else {
                    errorMessage = "No profiles found for this token."
                    isConnecting = false
                    return
                }

                try KeychainHelper.save(token: token, service: KeychainHelper.wiseService)

                profiles = fetchedProfiles
                selectedProfile = firstProfile
                connectedName = firstProfile.fullName
                isConnecting = false
                onConnected(firstProfile.fullName)

                logger.info("connected as \(firstProfile.fullName, privacy: .private)")
            } catch let error as WiseAPIError {
                errorMessage = error.localizedDescription
                isConnecting = false
                logger.error("connect failed: \(error.localizedDescription)")
            } catch {
                errorMessage = "Connection failed: \(error.localizedDescription)"
                isConnecting = false
                logger.error("connect failed: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    WiseConnectSheet { _ in }
}
