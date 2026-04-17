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
            } else {
                InsightsPreparingRow(month: summary.month)
            }
        case .generating(let partial):
            InsightsGeneratingView(month: summary.month, partial: partial)
        case .ready(let text):
            InsightsReadyView(text: text, onRegenerate: onRegenerate)
        case .error(let message):
            InsightsErrorView(message: message, onRegenerate: onRegenerate)
        }
    }
}
