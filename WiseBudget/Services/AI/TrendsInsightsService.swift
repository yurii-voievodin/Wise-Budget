import Foundation
import FoundationModels
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "TrendsInsights")

/// Generates trend narratives (growth / drops / unusual months) from a
/// `TrendsSummary`. Unlike the monthly service this is manually invoked —
/// callers decide when to call `generate(...)`. Cached in SwiftData keyed
/// by range + anchor.
@Observable
@MainActor
final class TrendsInsightsService {

    private static let instructions = """
    You are a concise personal-finance analyst. The user message lists \
    spending over several months, broken down by category. Respond in \
    Markdown bullets covering: 2 to 3 categories with the biggest \
    month-over-month growth, 2 to 3 categories with the biggest drops, any \
    unusual month, and one concrete, actionable suggestion. Use the currency \
    stated in the message. Do not invent numbers. Keep the whole response \
    under 150 words.
    """

    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        maximumResponseTokens: 280
    )

    enum State: Equatable {
        case idle
        case generating(String)
        case ready(String)
        case error(String)
    }

    private(set) var state: State = .idle

    /// Held so we can release the session when a generation is cancelled.
    private var activeSession: LanguageModelSession?

    /// Long-lived session used purely to call `prewarm()` and keep the
    /// on-device model loaded in memory between generations.
    private var warmupSession: LanguageModelSession?

    var availability: SpendingInsightsService.Availability {
        // Reuse the exact same availability logic — the underlying system model is shared.
        SpendingInsightsService.currentAvailability()
    }

    /// Loads the on-device model into memory ahead of the first `generate(...)`
    /// call. Safe to call repeatedly.
    func prewarm() {
        guard availability == .available else { return }
        if warmupSession == nil {
            warmupSession = LanguageModelSession(instructions: Self.instructions)
        }
        warmupSession?.prewarm()
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

        let prompt = summary.encodedAsPrompt()
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
            logger.debug("Cache hit for scope=\(scopeKey, privacy: .public)")
            state = .ready(cached)
            return
        }

        logger.debug("Sending prompt (scope=\(scopeKey, privacy: .public), \(prompt.count) chars):\n\(prompt, privacy: .public)")
        state = .generating("")

        let session = LanguageModelSession(instructions: Self.instructions)
        activeSession = session
        defer { if activeSession === session { activeSession = nil } }

        do {
            let stream = session.streamResponse(to: prompt, options: Self.generationOptions)
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
            logger.debug("Received response (\(latest.count) chars):\n\(latest, privacy: .public)")
            state = .ready(latest)
        } catch is CancellationError {
            state = .idle
            return
        } catch {
            logger.error("Generation failed: \(error.localizedDescription, privacy: .public)")
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
        let prompt = summary.encodedAsPrompt()
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
