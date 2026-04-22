import SwiftUI

struct TrendsSectionHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Trends Insights")
        }
    }
}
