import SwiftUI

struct ConnectionStatusPill: View {
    let isConnected: Bool
    let connectedName: String

    private var status: (label: String, tint: Color) {
        if isConnected {
            ("Connected", .green)
        } else if !connectedName.isEmpty {
            ("Needs Reconnect", .orange)
        } else {
            ("Not connected", .secondary)
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption)
            .padding(.horizontal, Layout.Spacing.small)
            .padding(.vertical, 2)
            .background(Capsule().fill(status.tint.opacity(0.18)))
            .foregroundStyle(status.tint)
    }
}
