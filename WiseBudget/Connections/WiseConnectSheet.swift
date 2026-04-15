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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Wise")
                .font(.headline)

            if connectedName != nil {
                profileSelectionView
            } else {
                tokenSetupView
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Spacer()

            VStack(spacing: 8) {
                if connectedName != nil {
                    Button("Done") {
                        saveSelections()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        connectAccount()
                    } label: {
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
                    .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)

                    Button("Cancel") {
                        dismiss()
                    }
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

    private var tokenSetupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Step 1
            VStack(alignment: .leading, spacing: 6) {
                Label("Step 1", systemImage: "1.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Open Wise settings and create an API token with read-only access.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Open wise.com") {
                    if let url = URL(string: "https://wise.com/settings/") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }

            Divider()

            // Step 2
            VStack(alignment: .leading, spacing: 6) {
                Label("Step 2", systemImage: "2.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Copy your personal API token and paste it below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SecureField("Paste your API token here", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var profileSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connected as \(connectedName ?? "")", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)

            if profiles.count > 1 {
                Divider()

                Text("Select profile to sync")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(profiles) { profile in
                    Button {
                        selectedProfile = profile
                    } label: {
                        HStack {
                            Image(systemName: selectedProfile?.id == profile.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedProfile?.id == profile.id ? .blue : .secondary)
                            Text("\(profile.fullName) (\(profile.type.capitalized))")
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(selectedProfile?.id == profile.id ? Color.accentColor.opacity(0.08) : Color.clear)
                        .clipShape(.rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text("Transfers for this profile will be synced automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func saveSelections() {
        if let profile = selectedProfile {
            WiseSyncService.saveSelectedProfileId(profile.id)
        }
        logger.info("saved profile selection")
    }

    private func connectAccount() {
        let trimmedToken = token.trimmingCharacters(in: .whitespaces)
        guard !trimmedToken.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let client = WiseAPIClient(token: trimmedToken)
                let fetchedProfiles = try await client.fetchProfiles()

                guard let firstProfile = fetchedProfiles.first else {
                    errorMessage = "No profiles found for this token."
                    isConnecting = false
                    return
                }

                try KeychainHelper.save(token: trimmedToken, service: KeychainHelper.wiseService)

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
