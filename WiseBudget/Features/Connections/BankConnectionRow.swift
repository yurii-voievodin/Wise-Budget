import SwiftUI

/// Single bank-card row: branding on the left, status + last-sync in the
/// middle, action buttons on the right. Both `BankConnectionsView` rows
/// (Monobank, Wise) share this layout so they read as a uniform list.
struct BankConnectionRow<Actions: View>: View {
    let title: String
    let iconSystemName: String
    let iconColor: Color
    let isConnected: Bool
    let connectedName: String
    let lastSync: TimeInterval
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.Radius.medium)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: iconSystemName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Layout.Spacing.small) {
                    Text(title)
                        .font(.headline)
                    ConnectionStatusPill(isConnected: isConnected, connectedName: connectedName)
                }
                if !connectedName.isEmpty {
                    Text(connectedName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isConnected, lastSync > 0 {
                    HStack(spacing: Layout.Spacing.tight) {
                        Image(systemName: "clock")
                        Text("Synced \(Date(timeIntervalSince1970: lastSync), style: .relative) ago")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: Layout.Spacing.small) {
                actions()
            }
        }
        .padding(.vertical, Layout.Spacing.tight)
    }
}

#Preview {
    Form {
        Section {
            BankConnectionRow(
                title: "Monobank",
                iconSystemName: "creditcard.fill",
                iconColor: .pink,
                isConnected: true,
                connectedName: "Воєводін Юрій",
                lastSync: Date.now.addingTimeInterval(-3600).timeIntervalSince1970
            ) {
                Button("Accounts") {}
                Button("Disconnect", role: .destructive) {}
            }
        }
        Section {
            BankConnectionRow(
                title: "Wise",
                iconSystemName: "globe",
                iconColor: .blue,
                isConnected: false,
                connectedName: "",
                lastSync: 0
            ) {
                Button("Connect") {}
                    .buttonStyle(.borderedProminent)
            }
        }
    }
    .formStyle(.grouped)
    .frame(width: 700, height: 320)
}
