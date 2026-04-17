import SwiftUI

struct InsightsSectionContent: View {
    let availability: SpendingInsightsService.Availability
    let state: SpendingInsightsService.State
    let summary: SpendingSummary
    let onRegenerate: () -> Void

    var body: some View {
        switch availability {
        case .available:
            InsightsStateView(state: state, summary: summary, onRegenerate: onRegenerate)
        case .appleIntelligenceNotEnabled:
            InsightsUnavailableRow(message: "Turn on Apple Intelligence in System Settings to see AI-generated insights.")
        case .deviceNotEligible:
            InsightsUnavailableRow(message: "This Mac doesn't support Apple Intelligence.")
        case .modelNotReady:
            InsightsUnavailableRow(message: "Apple Intelligence is preparing. Try again in a few minutes.")
        case .other(let reason):
            InsightsUnavailableRow(message: "Apple Intelligence unavailable: \(reason)")
        }
    }
}
