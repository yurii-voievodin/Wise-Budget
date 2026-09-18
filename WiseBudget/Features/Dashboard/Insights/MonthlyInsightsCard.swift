import SwiftUI
import SwiftData

struct MonthlyInsightsCard: View {
    let summary: SpendingSummary
    let scopeKey: String
    @AppStorage(SpendingInsightsService.userPreferenceKey) private var aiInsightsEnabled: Bool = SpendingInsightsService.userPreferenceDefault

    var body: some View {
        if aiInsightsEnabled {
            // The service is held inside a child view so its initializer
            // (which depends on FoundationModels) only runs when the user
            // has actually opted in. Keeps Xcode previews and machines
            // without Apple Intelligence from paying any cost.
            MonthlyInsightsContent(summary: summary, scopeKey: scopeKey)
        }
    }
}
