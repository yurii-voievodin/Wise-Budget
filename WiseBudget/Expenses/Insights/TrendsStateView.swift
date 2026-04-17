import SwiftUI

struct TrendsStateView: View {
    let state: TrendsInsightsService.State
    let summary: TrendsSummary
    let onGenerate: () -> Void

    var body: some View {
        switch state {
        case .idle:
            TrendsIdleRow(isEmpty: summary.isEmpty, onGenerate: onGenerate)
        case .generating(let partial):
            TrendsGeneratingView(rangeLabel: summary.rangeLabel, partial: partial)
        case .ready(let text):
            TrendsReadyView(text: text, onRegenerate: onGenerate)
        case .error(let message):
            TrendsErrorView(message: message, onRetry: onGenerate)
        }
    }
}
