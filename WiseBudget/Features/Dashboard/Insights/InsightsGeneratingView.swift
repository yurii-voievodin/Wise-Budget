import SwiftUI

struct InsightsGeneratingView: View {
    let month: String
    let partial: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analyzing \(month)…")
                    .foregroundStyle(.secondary)
            }
            if !partial.isEmpty {
                MarkdownText(partial)
                    .textSelection(.enabled)
            }
        }
    }
}
