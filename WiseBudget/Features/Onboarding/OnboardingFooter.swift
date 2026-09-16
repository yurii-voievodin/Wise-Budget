import SwiftUI

struct OnboardingFooter: View {
    let steps: [OnboardingFlowView.Step]
    let currentStep: OnboardingFlowView.Step
    let isLastStep: Bool
    let onSkip: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        HStack {
            Button("Skip", action: onSkip)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 7) {
                ForEach(steps) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                        .animation(Motion.settle, value: currentStep)
                }
            }
            .accessibilityHidden(true)

            Spacer()

            Button(isLastStep ? "Get Started" : "Continue", action: onAdvance)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, Layout.Spacing.large)
    }
}
