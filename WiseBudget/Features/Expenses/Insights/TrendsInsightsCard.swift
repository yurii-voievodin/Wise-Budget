import SwiftUI
import SwiftData

struct TrendsInsightsCard: View {
    let summary: TrendsSummary
    let kind: CachedInsightKind
    let scopeKey: String

    @Environment(\.modelContext) private var modelContext
    @State private var service = TrendsInsightsService()

    var body: some View {
        Section {
            TrendsSectionContent(
                availability: service.availability,
                state: service.state,
                summary: summary,
                onGenerate: generate
            )
        } header: {
            TrendsSectionHeader()
        }
        .task(id: scopeKey, loadCached)
    }

    private func generate() {
        Task { await service.generate(from: summary, kind: kind, scopeKey: scopeKey, in: modelContext) }
    }

    @Sendable
    private func loadCached() async {
        service.loadCached(from: summary, kind: kind, scopeKey: scopeKey, in: modelContext)
    }
}
