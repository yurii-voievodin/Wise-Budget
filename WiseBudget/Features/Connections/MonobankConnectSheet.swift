import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankConnect")

struct MonobankConnectSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("monobankSelectedAccounts") private var selectedAccountsData: String = ""

    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var connectedName: String?
    @State private var accounts: [MonobankAccount] = []
    @State private var selectedAccountIds: Set<String> = []

    var onConnected: (String) -> Void

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.large) {
            Text("Connect Monobank")
                .font(.headline)

            if let connectedName {
                MonobankAccountSelectionView(
                    connectedName: connectedName,
                    accounts: accounts,
                    selectedAccountIds: $selectedAccountIds
                )
            } else {
                MonobankTokenSetupView(token: $token)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Spacer()

            VStack(spacing: Layout.Spacing.small) {
                if connectedName != nil {
                    Button("Done", action: finishSelection)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(selectedAccountIds.isEmpty)
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
        .padding(Layout.Spacing.xLarge)
        .frame(minWidth: 380, idealWidth: 420, minHeight: 480, idealHeight: 560)
    }

    private func finishSelection() {
        saveSelectedAccounts()
        dismiss()
    }

    private func saveSelectedAccounts() {
        let ids = selectedAccountIds.sorted().joined(separator: ",")
        selectedAccountsData = ids
        Self.saveAccountDetails(accounts)
        logger.info("saved \(selectedAccountIds.count) selected accounts")
    }

    static func loadSelectedAccountIds() -> Set<String> {
        let stored = UserDefaults.standard.string(forKey: "monobankSelectedAccounts") ?? ""
        guard !stored.isEmpty else { return [] }
        return Set(stored.components(separatedBy: ","))
    }

    // MARK: - Account Details Cache

    struct CachedAccountDetail: Codable {
        let id: String
        let currencyCode: Int
        let iban: String?
    }

    /// Persists account id, currencyCode, and IBAN so sync can skip fetchClientInfo().
    static func saveAccountDetails(_ accounts: [MonobankAccount]) {
        let entries = accounts.map { CachedAccountDetail(id: $0.id, currencyCode: $0.currencyCode, iban: $0.iban) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "monobankAccountDetails")
        }
        logger.info("cached \(accounts.count) account details")
    }

    /// Loads cached account details. Returns nil if nothing is cached.
    static func loadAccountDetails() -> [(id: String, currencyCode: Int, iban: String?)]? {
        // Try new JSON format first
        if let data = UserDefaults.standard.data(forKey: "monobankAccountDetails"),
           let entries = try? JSONDecoder().decode([CachedAccountDetail].self, from: data),
           !entries.isEmpty {
            return entries.map { (id: $0.id, currencyCode: $0.currencyCode, iban: $0.iban) }
        }
        // Fall back to legacy comma-separated format for migration
        if let stored = UserDefaults.standard.string(forKey: "monobankAccountDetails"),
           !stored.isEmpty {
            let entries = stored.components(separatedBy: ",").compactMap { entry -> (id: String, currencyCode: Int, iban: String?)? in
                let parts = entry.components(separatedBy: ":")
                guard parts.count >= 2, let code = Int(parts[1]) else { return nil }
                let iban = parts.count >= 3 && !parts[2].isEmpty ? parts[2] : nil
                return (id: parts[0], currencyCode: code, iban: iban)
            }
            return entries.isEmpty ? nil : entries
        }
        return nil
    }

    // MARK: - Connect

    private func connectAccount() {
        let token = trimmedToken
        guard !token.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let client = MonobankAPIClient(token: token)
                let clientInfo = try await client.fetchClientInfo()

                try KeychainHelper.save(token: token, service: KeychainHelper.monobankService)

                let name = clientInfo.name ?? "Monobank User"
                connectedName = name
                accounts = clientInfo.accounts
                selectedAccountIds = Set(clientInfo.accounts.map(\.id))
                isConnecting = false
                onConnected(name)

                logger.info("connected as \(name, privacy: .private), \(clientInfo.accounts.count) accounts available")
            } catch let error as MonobankAPIError {
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
    MonobankConnectSheet { _ in }
}
