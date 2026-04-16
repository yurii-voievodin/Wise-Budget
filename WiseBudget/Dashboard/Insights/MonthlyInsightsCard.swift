import SwiftUI

struct MonthlyInsightsCard: View {
    let summary: SpendingSummary
    @State private var service = SpendingInsightsService()

    var body: some View {
        Section {
            InsightsSectionContent(
                availability: service.availability,
                state: service.state,
                summary: summary,
                onRegenerate: regenerate
            )
        } header: {
            InsightsSectionHeader()
        }
        .task(id: summary.month, autoGenerate)
    }

    private func regenerate() {
        Task { await service.generate(from: summary) }
    }

    @Sendable
    private func autoGenerate() async {
        guard service.availability == .available, !summary.isEmpty else { return }
        await service.generate(from: summary)
    }
}
