import Foundation

/// Composite key identifying a single cache row. `localeIdentifier` defaults to
/// `"en"` since prompts and hints are English-only today.
struct CacheKey: Equatable, Sendable {
    let kind: CachedInsightKind
    let scopeKey: String
    let currency: String
    let localeIdentifier: String

    init(kind: CachedInsightKind, scopeKey: String, currency: String, localeIdentifier: String = "en") {
        self.kind = kind
        self.scopeKey = scopeKey
        self.currency = currency
        self.localeIdentifier = localeIdentifier
    }
}
