import SwiftUI

struct InsightHintRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.Spacing.medium) {
            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(.tint)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
    }
}
