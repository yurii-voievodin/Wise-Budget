import SwiftUI
import SwiftData

struct MonthlyInsightsCard: View {
    let summary: SpendingSummary
    let scopeKey: String
    @Environment(\.modelContext) private var modelContext
    @State private var service = SpendingInsightsService()
    @State private var regenerateTask: Task<Void, Never>?

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
        .onAppear { service.prewarm() }
    }

    private func regenerate() {
        regenerateTask?.cancel()
        regenerateTask = Task {
            await service.generate(
                from: summary,
                scopeKey: scopeKey,
                in: modelContext,
                forceRefresh: true
            )
        }
    }

    @Sendable
    private func autoGenerate() async {
        guard service.availability == .available,
              summary.transactionCount >= SpendingInsightsService.minimumTransactionsForInsights
        else { return }
        await service.generate(from: summary, scopeKey: scopeKey, in: modelContext)
    }
}
