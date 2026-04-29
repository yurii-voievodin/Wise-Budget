import SwiftUI

struct InsightsReadyView: View {
    let hints: [String]
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InsightHintsList(hints: hints)
            HStack {
                Spacer()
                Button("Regenerate", action: onRegenerate)
                    .controlSize(.small)
            }
        }
    }
}
