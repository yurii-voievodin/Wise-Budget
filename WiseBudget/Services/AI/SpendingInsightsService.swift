import Foundation
import FoundationModels
import SwiftData

/// Wraps a Foundation Models `LanguageModelSession` to produce a short,
/// human-readable narrative about a `SpendingSummary`. Runs entirely on-device
/// and caches the result in SwiftData so repeated visits reuse it instantly.
@Observable
@MainActor
final class SpendingInsightsService {

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

    var availability: Availability { Self.currentAvailability() }

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

        let prompt: String
        do {
            prompt = try summary.encodedAsJSON()
        } catch {
            state = .error("Failed to prepare summary: \(error.localizedDescription)")
            return
        }

        let locale = InsightLocale.current()
        let hash = InsightsCache.hash(prompt)

        if forceRefresh {
            InsightsCache.invalidate(
                in: context,
                kind: .monthSummary,
                scopeKey: scopeKey,
                currency: summary.currency,
                localeIdentifier: locale.identifier
            )
        } else if let cached = InsightsCache.lookup(
            in: context,
            kind: .monthSummary,
            scopeKey: scopeKey,
            currency: summary.currency,
            localeIdentifier: locale.identifier,
            dataHash: hash
        ) {
            state = .ready(cached)
            return
        }

        state = .generating("")

        let session = LanguageModelSession(instructions: locale.monthlyInstructions)
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
                localeIdentifier: locale.identifier,
                dataHash: hash,
                content: latest
            )
            state = .ready(latest)
        } catch is CancellationError {
            // Navigated away mid-generation. Reset so the card doesn't get
            // stuck in `.generating` if the user returns to the same scope.
            state = .idle
            return
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
