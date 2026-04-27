import SwiftUI

struct InsightsEmptyRow: View {
    var message: String = "Add expenses or income to generate insights."

    var body: some View {
        Label(message, systemImage: "sparkles")
            .foregroundStyle(.secondary)
            .font(.callout)
    }
}
