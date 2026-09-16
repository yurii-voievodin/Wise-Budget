import SwiftUI

struct TransferBadge: View {
    var body: some View {
        Label("Transfer", systemImage: "arrow.left.arrow.right.circle.fill")
            .labelStyle(.iconOnly)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .help("Internal transfer — excluded from statistics")
            .accessibilityLabel("Internal transfer")
    }
}
