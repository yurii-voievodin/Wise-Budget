import Foundation

/// Payload ferried into a SwiftUI `WindowGroup(for: AIChatRequest.self)` via
/// `openWindow(id:value:)`. Carries the chosen provider plus the prompt text
/// that should be auto-pasted into its composer once the page loads.
struct AIChatRequest: Hashable, Codable, Identifiable {
    let provider: AIProvider
    let payload: String
    let createdAt: Date

    init(provider: AIProvider, payload: String, createdAt: Date = .now) {
        self.provider = provider
        self.payload = payload
        self.createdAt = createdAt
    }

    /// Stable per-request id so re-opening the same provider creates a
    /// fresh window instead of reusing the previous session.
    var id: String { "\(provider.rawValue)-\(createdAt.timeIntervalSince1970)" }
}
