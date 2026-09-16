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
        VStack(alignment: .leading, spacing: Layout.Spacing.large) {
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
        .padding(Layout.Spacing.xLarge)
        .frame(minWidth: 380, idealHeight: 400)
        .task(loadAccounts)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Loading accounts...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
            Spacer()
        } else {
            MonobankAccountSelectionList(
                accounts: accounts,
                selectedAccountIds: selectedAccountIds,
                onToggle: toggle
            )
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
