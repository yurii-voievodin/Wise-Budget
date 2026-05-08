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
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
        }
        .frame(width: 580, height: 520)
        .background(.background)
        .task {
            aiAvailability = SpendingInsightsService.currentAvailability()
            if currentStep == .ai && aiAvailability == .deviceNotEligible {
                advance()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .currency: OnboardingCurrencyStep()
        case .banks:    OnboardingBanksStep()
        case .ai:       OnboardingAIStep(availability: aiAvailability)
        case .budget:   OnboardingBudgetStep()
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip", action: complete)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 7) {
                ForEach(visibleSteps) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                        .animation(.easeOut(duration: 0.2), value: currentStep)
                }
            }

            Spacer()

            Button(isLastStep ? "Get Started" : "Continue") {
                if isLastStep {
                    complete()
                } else {
                    advance()
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func advance() {
        let next = visibleSteps.firstIndex(of: currentStep).map { $0 + 1 } ?? 0
        if next < visibleSteps.count {
            withAnimation(.easeInOut(duration: 0.2)) {
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

// MARK: - Step chrome

/// Shared layout for every step: hero icon, headline, supporting copy,
/// optional content slot for the step's interactive controls.
struct OnboardingStepLayout<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 72, height: 72)
            .padding(.top, 32)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)

            content()
                .padding(.horizontal, 40)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingFlowView()
        .modelContainer(PreviewSampleData.container)
        .environment(LocalAIAppDetector())
}
