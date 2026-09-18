import SwiftUI

struct InsightsGeneratingView: View {
    let month: String
    let hints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small) {
            HStack(spacing: Layout.Spacing.small) {
                ProgressView().controlSize(.small)
                Text("Analyzing \(month)…")
                    .foregroundStyle(.secondary)
            }
            if !hints.isEmpty {
                InsightHintsList(hints: hints)
            }
        }
    }
}
