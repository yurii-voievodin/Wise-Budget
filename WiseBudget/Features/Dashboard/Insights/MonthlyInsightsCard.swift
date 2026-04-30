import SwiftUI
import SwiftData

struct MonthlyInsightsCard: View {
    let summary: SpendingSummary
    let scopeKey: String
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SpendingInsightsService.userPreferenceKey) private var aiInsightsEnabled: Bool = SpendingInsightsService.userPreferenceDefault
    @State private var service = SpendingInsightsService()
    @State private var regenerateTask: Task<Void, Never>?

    var body: some View {
        if aiInsightsEnabled {
            Section {
                InsightsStateView(state: service.state, summary: summary, onRegenerate: regenerate)
            } header: {
                HStack {
                    InsightsSectionHeader()
                    Spacer()
                    if isReady {
                        Button(action: regenerate) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Regenerate insights")
                        .accessibilityLabel("Regenerate insights")
                    }
                }
                .textCase(nil)
            }
            .task(id: scopeKey, autoGenerate)
            .onAppear { service.prewarm() }
        }
    }

    private var isReady: Bool {
        if case .ready = service.state { return true }
        return false
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
        guard summary.transactionCount >= SpendingInsightsService.minimumTransactionsForInsights else { return }
        await service.generate(from: summary, scopeKey: scopeKey, in: modelContext)
    }
}
