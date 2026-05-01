import Foundation
import FoundationModels
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "SpendingInsights")

/// File-scope (not nested) and short `@Guide` text are deliberate per Apple
/// TN3193 — long descriptions inflate context size and add latency.
@Generable
struct InsightOutput: Equatable {
    @Guide(description: "Up to three short hints about the month's spending.")
    let hints: [String]
}

/// On-device generation; results cached in SwiftData via `InsightsCache`.
@Observable
@MainActor
final class SpendingInsightsService {

    private static let instructions = """
    You are looking at one month of the user's spending.

    The data below is already aggregated. Don't recompute totals or list \
    transactions back — the UI shows those. Mention only merchants and \
    amounts that appear above.

    Write up to three short hints — one sentence each — flagging the most \
    interesting facts of the month: a large one-off, a recurring pattern, a \
    category split, an unusual savings rate. Plain and specific, no advice.

    Use the currency at the top.
    """

    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        maximumResponseTokens: 600
    )

    /// Below this, the UI shows a static hint and the Ask AI handoff is disabled.
    static let minimumTransactionsForInsights = 5

    /// AppStorage source of truth for whether AI cards render. Only Settings
    /// flips this on, and only after checking Apple Intelligence availability.
    static let userPreferenceKey = "aiInsightsEnabled"
    static let userPreferenceDefault = false

    enum Availability: Equatable {
        case available
        case appleIntelligenceNotEnabled
        case deviceNotEligible
        case modelNotReady
        case other(String)
    }

    enum State: Equatable {
        case idle
        case generating([String])
        case ready([String])
        case error(String)
    }

    private(set) var state: State = .idle

    /// Held so we can release the session when a generation is cancelled.
    private var activeSession: LanguageModelSession?

    /// Long-lived session whose only job is keeping the model warm via `prewarm()`.
    private var warmupSession: LanguageModelSession?

    var availability: Availability { Self.currentAvailability() }

    /// Idempotent — subsequent calls are cheap no-ops.
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

    /// - Parameters:
    ///   - scopeKey: locale-independent month key, e.g. `"2026-03"`.
    ///   - forceRefresh: bypass the cache (used by the Regenerate button).
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

        if summary.isEmpty || summary.transactionCount < Self.minimumTransactionsForInsights {
            state = .idle
            return
        }

        let prompt = summary.encodedAsPrompt()
        let hash = InsightsCache.hash(prompt)
        let cacheKey = CacheKey(kind: .monthSummary, scopeKey: scopeKey, currency: summary.currency)

        if forceRefresh {
            InsightsCache.invalidate(in: context, key: cacheKey)
        } else if let cached = InsightsCache.lookup(in: context, key: cacheKey, dataHash: hash) {
            logger.debug("Cache hit for scope=\(scopeKey, privacy: .public)")
            state = .ready(Self.decodeCachedHints(cached))
            return
        }

        logger.debug("Sending prompt (scope=\(scopeKey, privacy: .public), \(prompt.count) chars):\n\(prompt, privacy: .public)")
        state = .generating([])

        let session = LanguageModelSession(instructions: Self.instructions)
        activeSession = session
        defer { if activeSession === session { activeSession = nil } }

        do {
            let stream = session.streamResponse(
                to: prompt,
                generating: InsightOutput.self,
                options: Self.generationOptions
            )
            var latestPartial: InsightOutput.PartiallyGenerated?
            for try await snapshot in stream {
                try Task.checkCancellation()
                latestPartial = snapshot.content
                state = .generating(snapshot.content.hints ?? [])
            }
            try Task.checkCancellation()
            let hints = (latestPartial?.hints ?? []).filter { !$0.isEmpty }
            // Stream cancelled between iterations — don't cache an empty card.
            guard !hints.isEmpty else {
                state = .idle
                return
            }
            let encoded = hints.joined(separator: "\n")
            InsightsCache.upsert(in: context, key: cacheKey, dataHash: hash, content: encoded)
            logger.debug("Received \(hints.count) hints:\n\(encoded, privacy: .public)")
            state = .ready(hints)
        } catch is CancellationError {
            // Navigated away mid-stream — avoid sticking the card in `.generating`.
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

    /// Decodes a cached payload back into hints. Tolerates the legacy markdown
    /// format (`* hint`) so entries written before the format change still
    /// render correctly.
    private static func decodeCachedHints(_ content: String) -> [String] {
        content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { line -> String in
                if line.hasPrefix("* ") { return String(line.dropFirst(2)) }
                if line.hasPrefix("- ") { return String(line.dropFirst(2)) }
                if line.hasPrefix("• ") { return String(line.dropFirst(2)) }
                return line
            }
            .filter { !$0.isEmpty }
    }
}
