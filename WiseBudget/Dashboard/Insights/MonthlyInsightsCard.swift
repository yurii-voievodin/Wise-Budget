import SwiftUI
import SwiftData

struct MonthlyInsightsCard: View {
    let summary: SpendingSummary
    let scopeKey: String
    @Environment(\.modelContext) private var modelContext
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
        .task(id: scopeKey, autoGenerate)
    }

    private func regenerate() {
        Task { await service.generate(from: summary, scopeKey: scopeKey, in: modelContext) }
    }

    @Sendable
    private func autoGenerate() async {
        guard service.availability == .available, !summary.isEmpty else { return }
        await service.generate(from: summary, scopeKey: scopeKey, in: modelContext)
    }
}
