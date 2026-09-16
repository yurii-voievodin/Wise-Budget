import SwiftUI
import SwiftData

struct MonthlyInsightsContent: View {
    let summary: SpendingSummary
    let scopeKey: String
    @Environment(\.modelContext) private var modelContext
    @State private var service = SpendingInsightsService()
    @State private var regenerateTask: Task<Void, Never>?

    var body: some View {
        Section {
            InsightsStateView(state: service.state, summary: summary, onRegenerate: regenerate)
        } header: {
            HStack(spacing: Layout.Spacing.snug) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Monthly Insights")
                Spacer()
                if isReady {
                    Button("Regenerate insights", systemImage: "arrow.clockwise", action: regenerate)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Regenerate insights")
                }
            }
            .textCase(nil)
        }
        .task(id: scopeKey, autoGenerate)
        .task { service.prewarm() }
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
        // Re-check availability here so a System Settings flip mid-session
        // leaves the card silent rather than surfacing a technical error.
        guard service.availability == .available,
              summary.transactionCount >= SpendingInsightsService.minimumTransactionsForInsights
        else { return }
        await service.generate(from: summary, scopeKey: scopeKey, in: modelContext)
    }
}
