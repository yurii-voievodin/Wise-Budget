import Foundation
import FoundationModels
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.wisebudget", category: "SpendingInsights")

/// File-scope (not nested) and short `@Guide` text are deliberate per Apple
/// TN3193 — long descriptions inflate context size and add latency.
@Generable
struct InsightOutput: Equatable {
    @Guide(description: "Specific observations about merchants, amounts, or patterns from the data.")
    let insights: [String]

    @Guide(description: "Actionable suggestions citing specific merchants or amounts from the data.")
    let recommendations: [String]
}

/// On-device generation; results cached in SwiftData via `InsightsCache`.
@Observable
@MainActor
final class SpendingInsightsService {

    private static let instructions = """
    You are a personal-finance coach reviewing one month of the user's spending.

    The data below is ALREADY AGGREGATED. Trust the numbers as given. Do not \
    recompute sums, do not invent merchants or amounts, do not list \
    transactions back to the user — the UI already shows them. Every \
    merchant or amount you mention must appear verbatim in the data above.

    Your job is narrative judgment: connect the dots between recurring \
    patterns, one-off expenses, and the savings rate, and tell the user the \
    story of their month. Bland "you spend a lot at X, switch to something \
    cheaper" is useless; a real coach connects facts.

    Rules:
    - If "Savings" is negative, the first insight must address what caused \
      the shortfall.
    - At least one insight must reference an entry from "Largest one-off \
      expenses" or "Possible duplicate or near-duplicate charges".
    - Recommendations are concrete actions for this week — not generic \
      advice. Never say "make a budget", "track your spending", "reduce \
      dining out", "plan meals", "switch to a cheaper alternative", \
      "consider cutting back", "set aside a portion of income", or "build \
      an emergency fund".

    Use the currency at the top. Keep total output under 150 words.
    """

    /// `.greedy` for cache determinism; 600 tokens to clear schema overhead
    /// and avoid Apple's "strict token limits cause malformed results" mode.
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
        case generating(String)
        case ready(String)
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
            let stream = session.streamResponse(
                to: prompt,
                generating: InsightOutput.self,
                options: Self.generationOptions
            )
            var latestPartial: InsightOutput.PartiallyGenerated?
            for try await snapshot in stream {
                try Task.checkCancellation()
                latestPartial = snapshot.content
                state = .generating(Self.renderMarkdown(from: snapshot.content))
            }
            try Task.checkCancellation()
            guard let final = latestPartial else {
                state = .idle
                return
            }
            let markdown = Self.renderMarkdown(from: final)
            // Stream cancelled between iterations — don't cache an empty card.
            guard !markdown.isEmpty else {
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
                content: markdown
            )
            logger.debug("Received response (\(markdown.count) chars):\n\(markdown, privacy: .public)")
            state = .ready(markdown)
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

    /// Headings only render once their section has an item — avoids flashing
    /// empty headers during streaming.
    private static func renderMarkdown(from partial: InsightOutput.PartiallyGenerated) -> String {
        var lines: [String] = []
        if let insights = partial.insights, !insights.isEmpty {
            lines.append("### Insights")
            for item in insights {
                lines.append("* \(item)")
            }
        }
        if let recommendations = partial.recommendations, !recommendations.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append("### Recommendations")
            for item in recommendations {
                lines.append("* \(item)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
