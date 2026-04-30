import SwiftUI

struct InsightsStateView: View {
    let state: SpendingInsightsService.State
    let summary: SpendingSummary
    let onRegenerate: () -> Void

    var body: some View {
        switch state {
        case .idle:
            if summary.isEmpty {
                InsightsEmptyRow()
            } else if summary.transactionCount < SpendingInsightsService.minimumTransactionsForInsights {
                InsightsEmptyRow(message: "Add a few more transactions this month to generate insights.")
            } else {
                InsightsPreparingRow(month: summary.month)
            }
        case .generating(let hints):
            InsightsGeneratingView(month: summary.month, hints: hints)
        case .ready(let hints):
            InsightsReadyView(hints: hints)
        case .error(let message):
            InsightsErrorView(message: message, onRegenerate: onRegenerate)
        }
    }
}
