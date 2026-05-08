import SwiftUI

struct OnboardingAIStep: View {
    let availability: SpendingInsightsService.Availability

    @AppStorage(SpendingInsightsService.userPreferenceKey) private var aiInsightsEnabled: Bool = SpendingInsightsService.userPreferenceDefault

    var body: some View {
        OnboardingStepLayout(
            icon: "sparkles",
            iconColor: .purple,
            title: "Apple Intelligence insights",
            subtitle: subtitle
        ) {
            VStack(spacing: 12) {
                Toggle(isOn: $aiInsightsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable AI Insights").fontWeight(.medium)
                        Text("Runs on-device. Nothing leaves your Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .disabled(availability != .available)

                if availability != .available {
                    Label(availabilityHint, systemImage: "sparkles.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .frame(maxWidth: 380)
        }
    }

    private var subtitle: String {
        switch availability {
        case .available:
            return "Get short, on-device hints about each month's spending. You can flip this off any time in Settings."
        case .deviceNotEligible:
            return "This Mac doesn't support Apple Intelligence. You'll still get every other feature — this step is just unavailable here."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence isn't enabled in System Settings yet. Turn it on there, then come back to enable insights."
        case .modelNotReady:
            return "Apple Intelligence is still preparing the model. Try again in a few minutes once it finishes downloading."
        case .other:
            return "Apple Intelligence is unavailable right now. You can revisit this in Settings later."
        }
    }

    private var availabilityHint: String {
        switch availability {
        case .available: ""
        case .appleIntelligenceNotEnabled: "Open System Settings → Apple Intelligence to turn it on."
        case .deviceNotEligible: "Hardware-restricted to recent Apple silicon."
        case .modelNotReady: "The on-device model is still downloading."
        case .other(let reason): "Reason: \(reason)"
        }
    }
}

#Preview("Available") {
    OnboardingAIStep(availability: .available)
        .frame(width: 580, height: 460)
}

#Preview("Not enabled") {
    OnboardingAIStep(availability: .appleIntelligenceNotEnabled)
        .frame(width: 580, height: 460)
}
