import SwiftUI

struct TrendsSectionContent: View {
    let availability: SpendingInsightsService.Availability
    let state: TrendsInsightsService.State
    let summary: TrendsSummary
    let onGenerate: () -> Void

    var body: some View {
        switch availability {
        case .available:
            TrendsStateView(state: state, summary: summary, onGenerate: onGenerate)
        case .appleIntelligenceNotEnabled:
            TrendsUnavailableRow(message: "Turn on Apple Intelligence in System Settings to see AI-generated trends.")
        case .deviceNotEligible:
            TrendsUnavailableRow(message: "This Mac doesn't support Apple Intelligence.")
        case .modelNotReady:
            TrendsUnavailableRow(message: "Apple Intelligence is preparing. Try again in a few minutes.")
        case .other(let reason):
            TrendsUnavailableRow(message: "Apple Intelligence unavailable: \(reason)")
        }
    }
}
