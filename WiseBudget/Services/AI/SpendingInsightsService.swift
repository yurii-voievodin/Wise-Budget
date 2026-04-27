import Foundation
import FoundationModels
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "SpendingInsights")

/// Wraps a Foundation Models `LanguageModelSession` to produce a short,
/// human-readable narrative about a `SpendingSummary`. Runs entirely on-device
/// and caches the result in SwiftData so repeated visits reuse it instantly.
@Observable
@MainActor
final class SpendingInsightsService {

    private static let instructions = """
    You are a concise personal-finance analyst. The user message lists one \
    month of expenses and incomes. Respond with 3 to 5 short bullet points \
    covering: the biggest spending categories, anything unusual, and one \
    concrete suggestion. Use the currency stated in the message. Do not \
    invent numbers. Keep the whole response under 120 words.
    """

    /// `.greedy` sampling is deterministic (improves cache hit rate against
    /// `InsightsCache`) and slightly faster than nucleus sampling.
    /// `maximumResponseTokens` caps worst-case latency: at ~30 tok/s on
    /// modern devices, 220 tokens covers the 120-word ceiling with headroom.
    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        maximumResponseTokens: 220
    )

    /// Below this transaction count there isn't enough signal for the model to
    /// produce a useful narrative — the UI shows a static hint instead and the
    /// Ask AI handoff is disabled.
    static let minimumTransactionsForInsights = 5

    enum Availability: Equatable {
        case available
        case appleIntelligenceNotEnabled
        case deviceNotEligible
        case modelNotReady
        case other(String)
    }

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

    var availability: Availability { Self.currentAvailability() }

    /// Loads the on-device model into memory ahead of the first `generate(...)`
    /// call. Apple reports up to ~40% reduction in time-to-first-token. Safe
    /// to call repeatedly; subsequent calls are cheap no-ops.
    func prewarm() {
        guard availability == .available else { return }
        if warmupSession == nil {
            warmupSession = LanguageModelSession(instructions: Self.instructions)
        }
        warmupSession?.prewarm()
    }

    static func currentAvailability() -> Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(let other):
            return .other(String(describing: other))
        }
    }

    /// Generates or reuses a cached insight for the given month summary.
    /// - Parameters:
    ///   - summary: aggregated totals + top categories for the month.
    ///   - scopeKey: locale-independent month key, e.g. `"2026-03"`.
    ///   - context: SwiftData context used for cache lookup and persistence.
    ///   - forceRefresh: when `true`, evict any cached row and run the model again.
    ///     Used by the "Regenerate" button.
    func generate(
        from summary: SpendingSummary,
        scopeKey: String,
        in context: ModelContext,
        forceRefresh: Bool = false
    ) async {
        guard availability == .available else {
            state = .error("Apple Intelligence is not available.")
            return
        }

        if summary.isEmpty {
            state = .ready("No transactions recorded for \(summary.month).")
            return
        }

        if summary.transactionCount < Self.minimumTransactionsForInsights {
            state = .idle
            return
        }

        let prompt = summary.encodedAsPrompt()
        let hash = InsightsCache.hash(prompt)

        if forceRefresh {
            InsightsCache.invalidate(
                in: context,
                kind: .monthSummary,
                scopeKey: scopeKey,
                currency: summary.currency,
                localeIdentifier: "en"
            )
        } else if let cached = InsightsCache.lookup(
            in: context,
            kind: .monthSummary,
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
            // Don't cache or present empty output (e.g. stream ended with no
            // partials because the task was cancelled between iterations).
            guard !latest.isEmpty else {
                state = .idle
                return
            }
            InsightsCache.upsert(
                in: context,
                kind: .monthSummary,
                scopeKey: scopeKey,
                currency: summary.currency,
                localeIdentifier: "en",
                dataHash: hash,
                content: latest
            )
            logger.debug("Received response (\(latest.count) chars):\n\(latest, privacy: .public)")
            state = .ready(latest)
        } catch is CancellationError {
            // Navigated away mid-generation. Reset so the card doesn't get
            // stuck in `.generating` if the user returns to the same scope.
            state = .idle
            return
        } catch {
            logger.error("Generation failed: \(error.localizedDescription, privacy: .public)")
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
