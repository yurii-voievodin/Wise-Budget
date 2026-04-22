import SwiftUI

struct InsightsEmptyRow: View {
    var body: some View {
        Label("Add expenses or income to generate insights.", systemImage: "sparkles")
            .foregroundStyle(.secondary)
            .font(.callout)
    }
}
