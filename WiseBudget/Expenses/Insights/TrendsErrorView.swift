import SwiftUI

struct TrendsErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
            HStack {
                Spacer()
                Button("Try Again", action: onRetry)
                    .controlSize(.small)
            }
        }
    }
}
