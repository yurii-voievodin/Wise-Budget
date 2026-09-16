import SwiftUI

struct OnboardingStepContent: View {
    let step: OnboardingFlowView.Step
    let aiAvailability: SpendingInsightsService.Availability

    var body: some View {
        switch step {
        case .currency: OnboardingCurrencyStep()
        case .banks:    OnboardingBanksStep()
        case .ai:       OnboardingAIStep(availability: aiAvailability)
        case .budget:   OnboardingBudgetStep()
        }
    }
}
