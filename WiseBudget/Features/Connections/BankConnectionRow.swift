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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: iconSystemName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    statusPill
                }
                if !connectedName.isEmpty {
                    Text(connectedName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isConnected, lastSync > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("Synced \(Date(timeIntervalSince1970: lastSync), style: .relative) ago")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                actions()
            }
        }
        .padding(.vertical, 4)
    }

    private var statusPill: some View {
        let (label, tint): (String, Color) = if isConnected {
            ("Connected", .green)
        } else if !connectedName.isEmpty {
            ("Needs Reconnect", .orange)
        } else {
            ("Not connected", .secondary)
        }

        return Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.18)))
            .foregroundStyle(tint)
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
