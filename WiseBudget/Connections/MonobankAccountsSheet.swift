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

            content

            HStack {
                Button("Cancel", action: dismiss.callAsFunction)
                    .buttonStyle(.bordered)

                Spacer()

                Button("Save", action: saveAndClose)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAccountIds.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealHeight: 400)
        .task(loadAccounts)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
            Spacer()
        } else {
            accountList
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView("Loading accounts...")
                Spacer()
            }
            Spacer()
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select which accounts to sync")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(accounts) { account in
                        MonobankAccountRow(
                            account: account,
                            isSelected: selectedAccountIds.contains(account.id),
                            onToggle: { toggle(account) }
                        )
                    }
                }
            }
        }
    }

    private func toggle(_ account: MonobankAccount) {
        if selectedAccountIds.contains(account.id) {
            selectedAccountIds.remove(account.id)
        } else {
            selectedAccountIds.insert(account.id)
        }
    }

    @Sendable
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
