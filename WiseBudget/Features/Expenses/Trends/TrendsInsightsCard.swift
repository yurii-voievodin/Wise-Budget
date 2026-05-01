import SwiftUI
import SwiftData

struct TrendsInsightsCard: View {
    let summary: TrendsSummary
    let kind: CachedInsightKind
    let scopeKey: String

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SpendingInsightsService.userPreferenceKey) private var aiInsightsEnabled: Bool = SpendingInsightsService.userPreferenceDefault
    @State private var service = TrendsInsightsService()

    var body: some View {
        if aiInsightsEnabled {
            Section {
                TrendsStateView(state: service.state, summary: summary, onGenerate: generate)
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Trends Insights")
                }
            }
            .task(id: scopeKey, loadCached)
            .onAppear { service.prewarm() }
        }
    }

    private func generate() {
        Task { await service.generate(from: summary, kind: kind, scopeKey: scopeKey, in: modelContext) }
    }

    @Sendable
    private func loadCached() async {
        service.loadCached(from: summary, kind: kind, scopeKey: scopeKey, in: modelContext)
    }
}
