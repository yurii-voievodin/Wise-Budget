import SwiftUI

struct InsightsErrorView: View {
    let message: String
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            HStack {
                Spacer()
                Button("Try Again", action: onRegenerate)
                    .controlSize(.small)
            }
        }
    }
}
