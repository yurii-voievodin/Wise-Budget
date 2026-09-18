import SwiftUI
import SwiftData

/// Four-step welcome flow shown on first launch and re-runnable from
/// Help → Show Onboarding. Every step is skippable; closing the flow
/// flips `hasCompletedOnboarding` so the sheet doesn't return on its own.
struct OnboardingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OnboardingFlowView.completedKey) private var hasCompletedOnboarding: Bool = false

    @State private var currentStep: Step = .currency
    @State private var aiAvailability: SpendingInsightsService.Availability = .modelNotReady

    static let completedKey = "hasCompletedOnboarding"

    enum Step: Int, CaseIterable, Identifiable, Hashable {
        case currency
        case banks
        case ai
        case budget

        var id: Self { self }
    }

    /// Drop the AI step on devices that can't run Apple Intelligence so the
    /// progress dots match what the user actually sees.
    private var visibleSteps: [Step] {
        Step.allCases.filter { step in
            step != .ai || aiAvailability != .deviceNotEligible
        }
    }

    private var currentIndex: Int {
        visibleSteps.firstIndex(of: currentStep) ?? 0
    }

    private var isLastStep: Bool {
        currentIndex == visibleSteps.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepContent(step: currentStep, aiAvailability: aiAvailability)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            OnboardingFooter(
                steps: visibleSteps,
                currentStep: currentStep,
                isLastStep: isLastStep,
                onSkip: complete,
                onAdvance: advanceOrComplete
            )
        }
        .frame(minWidth: 580, idealWidth: 580, minHeight: 520, idealHeight: 520)
        .background(.background)
        .task {
            aiAvailability = SpendingInsightsService.currentAvailability()
            if currentStep == .ai && aiAvailability == .deviceNotEligible {
                advance()
            }
        }
    }

    private func advanceOrComplete() {
        if isLastStep {
            complete()
        } else {
            advance()
        }
    }

    private func advance() {
        let next = currentIndex + 1
        if next < visibleSteps.count {
            withAnimation(Motion.standard) {
                currentStep = visibleSteps[next]
            }
        } else {
            complete()
        }
    }

    private func complete() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingFlowView()
        .modelContainer(PreviewSampleData.container)
        .environment(LocalAIAppDetector())
}
