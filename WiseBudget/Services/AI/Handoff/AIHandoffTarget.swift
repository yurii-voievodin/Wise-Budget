import Foundation

/// A specific handoff destination for an `AIProvider` — either the native
/// macOS app (when installed) or the web/browser flow. The toolbar uses
/// these as menu rows and persists the last-picked target so it floats to
/// the top next time.
struct AIHandoffTarget: Hashable, Identifiable, Sendable {
    enum Destination: String, Hashable, Sendable {
        case nativeApp
        case web
    }

    let provider: AIProvider
    let destination: Destination

    var id: String { "\(provider.rawValue)-\(destination.rawValue)" }
}
