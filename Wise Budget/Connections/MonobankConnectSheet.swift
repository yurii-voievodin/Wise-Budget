import SwiftUI
import AppKit
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Monobank")
                .font(.headline)

            if connectedName != nil {
                // Step 3: Account selection
                accountSelectionView
            } else {
                // Steps 1 & 2: Token setup
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
                        saveSelectedAccounts()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(selectedAccountIds.isEmpty)
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
        .frame(width: 380, height: 480)
    }

    private var tokenSetupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Step 1
            VStack(alignment: .leading, spacing: 6) {
                Label("Step 1", systemImage: "1.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Open the Monobank API portal and log in with your phone number.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Open api.monobank.ua") {
                    if let url = URL(string: "https://api.monobank.ua/") {
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

                Text("Copy your personal token and paste it below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SecureField("API token", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var accountSelectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connected as \(connectedName!)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)

            Divider()

            Text("Select accounts to sync")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(accounts) { account in
                        accountRow(account)
                    }
                }
            }
        }
    }

    private func accountRow(_ account: MonobankAccount) -> some View {
        let isSelected = selectedAccountIds.contains(account.id)
        let currency = MonobankAPIClient.currencyString(for: account.currencyCode)
        let balance = Decimal(account.balance) / 100
        let maskedPan = account.maskedPan?.first ?? ""

        return Button {
            if isSelected {
                selectedAccountIds.remove(account.id)
            } else {
                selectedAccountIds.insert(account.id)
            }
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(accountLabel(account))
                        .font(.callout)
                    if !maskedPan.isEmpty {
                        Text(maskedPan)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("\(balance as NSDecimalNumber, formatter: Self.balanceFormatter) \(currency)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private func accountLabel(_ account: MonobankAccount) -> String {
        let currency = MonobankAPIClient.currencyString(for: account.currencyCode)
        if let type = account.type {
            return "\(type.capitalized) (\(currency))"
        }
        return currency
    }

    private static let balanceFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

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

    /// Persists account id→currencyCode mapping so sync can skip fetchClientInfo().
    static func saveAccountDetails(_ accounts: [MonobankAccount]) {
        let entries = accounts.map { "\($0.id):\($0.currencyCode)" }
        UserDefaults.standard.set(entries.joined(separator: ","), forKey: "monobankAccountDetails")
        logger.info("cached \(accounts.count) account details")
    }

    /// Loads cached account details. Returns nil if nothing is cached.
    static func loadAccountDetails() -> [(id: String, currencyCode: Int)]? {
        guard let stored = UserDefaults.standard.string(forKey: "monobankAccountDetails"),
              !stored.isEmpty else { return nil }
        let entries = stored.components(separatedBy: ",").compactMap { entry -> (id: String, currencyCode: Int)? in
            let parts = entry.components(separatedBy: ":")
            guard parts.count == 2, let code = Int(parts[1]) else { return nil }
            return (id: parts[0], currencyCode: code)
        }
        return entries.isEmpty ? nil : entries
    }

    private func connectAccount() {
        let trimmedToken = token.trimmingCharacters(in: .whitespaces)
        guard !trimmedToken.isEmpty else { return }

        isConnecting = true
        errorMessage = nil

        Task {
            do {
                let client = MonobankAPIClient(token: trimmedToken)
                let clientInfo = try await client.fetchClientInfo()

                try KeychainHelper.save(token: trimmedToken, service: KeychainHelper.monobankService)

                await MainActor.run {
                    connectedName = clientInfo.name ?? "Monobank User"
                    accounts = clientInfo.accounts
                    // Pre-select all accounts
                    selectedAccountIds = Set(clientInfo.accounts.map { $0.id })
                    isConnecting = false
                    onConnected(connectedName!)
                }

                logger.info("connected as \(clientInfo.name ?? "unknown", privacy: .private), \(clientInfo.accounts.count) accounts available")
            } catch let error as MonobankAPIError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isConnecting = false
                }
                logger.error("connect failed: \(error.localizedDescription)")
            } catch {
                await MainActor.run {
                    errorMessage = "Connection failed: \(error.localizedDescription)"
                    isConnecting = false
                }
                logger.error("connect failed: \(error.localizedDescription)")
            }
        }
    }
}
