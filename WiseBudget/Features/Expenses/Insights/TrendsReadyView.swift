import SwiftUI

struct TrendsReadyView: View {
    let text: String
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(text)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button("Regenerate", action: onRegenerate)
                    .controlSize(.small)
            }
        }
    }
}
