import SwiftUI

struct TransactionSourceBadge: View {
    let source: TransactionSource

    init(externalId: String?) {
        self.source = TransactionSource(externalId: externalId)
    }

    init(source: TransactionSource) {
        self.source = source
    }

    var body: some View {
        switch source {
        case .manualOrCSV:
            EmptyView()
        case .wiseSync:
            monogram("W", help: "Synced from Wise")
        case .monobankSync:
            monogram("M", help: "Synced from Monobank")
        }
    }

    private func monogram(_ letter: String, help: String) -> some View {
        Text(letter)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 0.5)
            )
            .help(help)
            .accessibilityLabel(help)
    }
}
