import Foundation
import CryptoKit
import SwiftData

/// Thin helper around `ModelContext` for reading/writing `CachedInsight` rows.
/// All lookups match on the full composite key except `dataHash`, which is the
/// invalidation signal: a row with the same scope but a stale hash is replaced.
enum InsightsCache {

    /// Returns the cached content only if the current data hash matches
    /// and the stored content is non-empty. Returns `nil` on cache miss,
    /// stale hash, or empty content (which may have been written by a
    /// cancelled generation and should be regenerated).
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
        guard existing.dataHash == dataHash, !existing.content.isEmpty else {
            return nil
        }
        return existing.content
    }

    /// Creates or replaces the cached content for the given scope.
    /// Keeps at most one row per `(kind, scopeKey, currency, localeIdentifier)`.
    /// Empty content is ignored — callers may cancel mid-stream with no text yet.
    static func upsert(
        in context: ModelContext,
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String,
        dataHash: String,
        content: String
    ) {
        guard !content.isEmpty else { return }
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

    /// Deletes the cached row for the given scope, if any. Used by "Regenerate"
    /// to force the next `generate(...)` call to hit the model instead of
    /// returning the previously stored content.
    static func invalidate(
        in context: ModelContext,
        kind: CachedInsightKind,
        scopeKey: String,
        currency: String,
        localeIdentifier: String
    ) {
        if let existing = fetch(
            in: context,
            kind: kind,
            scopeKey: scopeKey,
            currency: currency,
            localeIdentifier: localeIdentifier
        ) {
            context.delete(existing)
            try? context.save()
        }
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
