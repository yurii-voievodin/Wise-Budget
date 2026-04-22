import SwiftUI

struct TrendsGeneratingView: View {
    let rangeLabel: String
    let partial: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Analyzing \(rangeLabel)…")
                    .foregroundStyle(.secondary)
            }
            if !partial.isEmpty {
                MarkdownText(partial)
                    .textSelection(.enabled)
            }
        }
    }
}
