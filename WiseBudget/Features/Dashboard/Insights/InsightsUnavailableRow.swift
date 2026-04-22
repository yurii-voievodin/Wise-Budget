import SwiftUI

struct InsightsUnavailableRow: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "sparkles.slash")
            .foregroundStyle(.secondary)
            .font(.callout)
    }
}
