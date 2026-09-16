import SwiftUI

/// Shared layout for every step: hero icon, headline, supporting copy,
/// optional content slot for the step's interactive controls.
struct OnboardingStepLayout<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: Double = 72

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(iconColor.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: heroSize * 0.44, weight: .medium))
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
            }
            .frame(width: heroSize, height: heroSize)
            .padding(.top, 32)

            VStack(spacing: Layout.Spacing.snug) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)

            content
                .padding(.horizontal, 40)
                .padding(.top, Layout.Spacing.tight)

            Spacer(minLength: 0)
        }
    }
}
