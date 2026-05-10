import SwiftUI
import StoreKit

/// Schedules the system review prompt after the user has completed onboarding
/// and launched the app a few more times. Apple still rate-limits the actual
/// dialog (3×/year), this just decides when we'd *like* to ask.
struct ReviewPromptModifier: ViewModifier {
    private static let launchCountKey = "reviewPrompt.launchesAfterOnboarding"
    private static let askedKey = "reviewPrompt.asked"
    private static let launchesBeforeAsking = 1

    @AppStorage(OnboardingFlowView.completedKey) private var hasCompletedOnboarding: Bool = false

    @Environment(\.requestReview) private var requestReview

    func body(content: Content) -> some View {
        content.task {
            guard hasCompletedOnboarding else { return }
            let defaults = UserDefaults.standard
            guard !defaults.bool(forKey: Self.askedKey) else { return }
            let next = defaults.integer(forKey: Self.launchCountKey) + 1
            defaults.set(next, forKey: Self.launchCountKey)
            guard next >= Self.launchesBeforeAsking else { return }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            requestReview()
            defaults.set(true, forKey: Self.askedKey)
        }
    }
}

extension View {
    func reviewPrompt() -> some View {
        modifier(ReviewPromptModifier())
    }
}
