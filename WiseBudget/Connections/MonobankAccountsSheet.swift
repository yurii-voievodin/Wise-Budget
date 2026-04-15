import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.wisebudget", category: "MonobankAccounts")

struct MonobankAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("monobankSelectedAccounts") private var selectedAccountsData: String = ""

    @State private var accounts: [MonobankAccount] = []
    @State private var selectedAccountIds: Set<String> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monobank Accounts")
                .font(.headline)

            if isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Loading accounts...")
                    Spacer()
                }
                Spacer()
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                Spacer()
            } else {
                Text("Select which accounts to sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(accounts) { account in
                            accountRow(account)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveAndClose()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAccountIds.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 400)
        .task {
            await loadAccounts()
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
            .clipShape(.rect(cornerRadius: 6))
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

    private func loadAccounts() async {
        selectedAccountIds = MonobankConnectSheet.loadSelectedAccountIds()

        do {
            guard let token = KeychainHelper.loadToken(service: KeychainHelper.monobankService) else {
                errorMessage = "No token found. Please reconnect."
                isLoading = false
                return
            }

            let client = MonobankAPIClient(token: token)
            let clientInfo = try await client.fetchClientInfo()

            accounts = clientInfo.accounts
            isLoading = false

            logger.debug("loaded \(clientInfo.accounts.count) accounts")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            logger.error("failed to load accounts: \(error.localizedDescription)")
        }
    }

    private func saveAndClose() {
        let ids = selectedAccountIds.sorted().joined(separator: ",")
        selectedAccountsData = ids
        MonobankConnectSheet.saveAccountDetails(accounts)
        logger.info("updated account selection: \(selectedAccountIds.count) accounts")
        dismiss()
    }
}

#Preview {
    MonobankAccountsSheet()
}
