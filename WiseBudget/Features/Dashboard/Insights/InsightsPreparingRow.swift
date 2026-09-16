import SwiftUI

struct InsightsPreparingRow: View {
    let month: String

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            ProgressView().controlSize(.small)
            Text("Preparing insights for \(month)…")
                .foregroundStyle(.secondary)
        }
    }
}
