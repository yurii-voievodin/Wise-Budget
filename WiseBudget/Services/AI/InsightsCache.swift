import Foundation
import CryptoKit
import SwiftData

/// Thin helper around `ModelContext` for reading/writing `CachedInsight` rows.
/// All lookups match on the full composite key except `dataHash`, which is the
/// invalidation signal: a row with the same scope but a stale hash is replaced.
enum InsightsCache {

    /// Returns the cached content only if the current data hash matches.
    /// Returns `nil` on cache miss or if the stored hash is stale.
    static func lookup(
        in context: ModelContext,
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String,
        dataHash: String
    ) -> String? {
        guard let existing = fetch(
            in: context,
            kind: kind,
            scopeKey: scopeKey,
            currency: currency,
            localeIdentifier: localeIdentifier
        ) else {
            return nil
        }
        return existing.dataHash == dataHash ? existing.content : nil
    }

    /// Creates or replaces the cached content for the given scope.
    /// Keeps at most one row per `(kind, scopeKey, currency, localeIdentifier)`.
    static func upsert(
        in context: ModelContext,
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String,
        dataHash: String,
        content: String
    ) {
        if let existing = fetch(
            in: context,
            kind: kind,
            scopeKey: scopeKey,
            currency: currency,
            localeIdentifier: localeIdentifier
        ) {
            existing.dataHash = dataHash
            existing.content = content
            existing.createdAt = .now
        } else {
            let row = CachedInsight(
                kind: kind,
                scopeKey: scopeKey,
                currency: currency,
                localeIdentifier: localeIdentifier,
                dataHash: dataHash,
                content: content
            )
            context.insert(row)
        }
        try? context.save()
    }

    private static func fetch(
        in context: ModelContext,
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String
    ) -> CachedInsight? {
        let kindRaw = kind.rawValue
        // Note: SwiftData #Predicate currently crashes on multi-field equality
        // captured from local variables (FB14…). Filter in memory instead —
        // the cache table stays small (one row per scope).
        let all = (try? context.fetch(FetchDescriptor<CachedInsight>())) ?? []
        return all.first { row in
            row.kindRaw == kindRaw
                && row.scopeKey == scopeKey
                && row.currency == currency
                && row.localeIdentifier == localeIdentifier
        }
    }

    /// Computes a stable SHA256 hex digest of the given JSON string.
    /// Used as the cache-invalidation signal: any change in the payload
    /// (new expense, edit, delete) produces a different hash.
    static func hash(_ payload: String) -> String {
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
