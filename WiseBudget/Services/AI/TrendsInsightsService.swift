import Foundation
import FoundationModels
import SwiftData

/// Generates trend narratives (growth / drops / unusual months) from a
/// `TrendsSummary`. Unlike the monthly service this is manually invoked —
/// callers decide when to call `generate(...)`. Cached in SwiftData keyed
/// by range + anchor.
@Observable
@MainActor
final class TrendsInsightsService {

    private static let instructions = """
    You are a concise personal-finance analyst. You will receive a JSON summary \
    of spending over several months, broken down by category. Respond in Markdown \
    bullets and cover: 2 to 3 categories with the biggest month-over-month \
    growth, 2 to 3 categories with the biggest drops, any unusual month, and end \
    with one concrete, actionable suggestion. Use the currency provided in the \
    JSON. Do not invent numbers. Keep the whole response under 150 words.
    """

    enum State: Equatable {
        case idle
        case generating(String)
        case ready(String)
        case error(String)
    }

    private(set) var state: State = .idle

    /// Held so we can release the session when a generation is cancelled.
    private var activeSession: LanguageModelSession?

    var availability: SpendingInsightsService.Availability {
        // Reuse the exact same availability logic — the underlying system model is shared.
        SpendingInsightsService.currentAvailability()
    }

    /// Resets the state to `.idle`. Called when the range switches.
    func reset() {
        state = .idle
    }

    func generate(
        from summary: TrendsSummary,
        kind: CachedInsightKind,
        scopeKey: String,
        in context: ModelContext,
        forceRefresh: Bool = false
    ) async {
        guard availability == .available else {
            state = .error("Apple Intelligence is not available.")
            return
        }

        if summary.isEmpty {
            state = .ready("No expense data to analyze for \(summary.rangeLabel).")
            return
        }

        let prompt: String
        do {
            prompt = try summary.encodedAsJSON()
        } catch {
            state = .error("Failed to prepare trends payload: \(error.localizedDescription)")
            return
        }

        let hash = InsightsCache.hash(prompt)

        if forceRefresh {
            InsightsCache.invalidate(
                in: context,
                kind: kind,
                scopeKey: scopeKey,
                currency: summary.currency,
                localeIdentifier: "en"
            )
        } else if let cached = InsightsCache.lookup(
            in: context,
            kind: kind,
            scopeKey: scopeKey,
            currency: summary.currency,
            localeIdentifier: "en",
            dataHash: hash
        ) {
            state = .ready(cached)
            return
        }

        state = .generating("")

        let session = LanguageModelSession(instructions: Self.instructions)
        activeSession = session
        defer { if activeSession === session { activeSession = nil } }

        do {
            let stream = session.streamResponse(to: prompt)
            var latest = ""
            for try await partial in stream {
                try Task.checkCancellation()
                latest = partial.content
                state = .generating(latest)
            }
            try Task.checkCancellation()
            guard !latest.isEmpty else {
                state = .idle
                return
            }
            InsightsCache.upsert(
                in: context,
                kind: kind,
                scopeKey: scopeKey,
                currency: summary.currency,
                localeIdentifier: "en",
                dataHash: hash,
                content: latest
            )
            state = .ready(latest)
        } catch is CancellationError {
            state = .idle
            return
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Attempts a cache-only lookup without generating. Used when the range
    /// switches so we can preload a previously-generated insight instantly.
    func loadCached(
        from summary: TrendsSummary,
        kind: CachedInsightKind,
        scopeKey: String,
        in context: ModelContext
    ) {
        guard let prompt = try? summary.encodedAsJSON() else {
            state = .idle
            return
        }
        let hash = InsightsCache.hash(prompt)
        if let cached = InsightsCache.lookup(
            in: context,
            kind: kind,
            scopeKey: scopeKey,
            currency: summary.currency,
            localeIdentifier: "en",
            dataHash: hash
        ) {
            state = .ready(cached)
        } else {
            state = .idle
        }
    }
}
