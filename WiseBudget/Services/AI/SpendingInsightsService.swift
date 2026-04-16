import Foundation
import FoundationModels

/// Wraps a Foundation Models `LanguageModelSession` to produce a short, human-readable
/// narrative about a `SpendingSummary`. Runs entirely on-device.
@Observable
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
        case generating(String)     // partial streamed text
        case ready(String)
        case error(String)
    }

    private(set) var state: State = .idle

    var availability: Availability {
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

    private static let instructions = """
    You are a concise personal-finance analyst. You will receive a JSON summary \
    of one month of the user's expenses and incomes. Respond with 3 to 5 short \
    bullet points covering: the biggest spending categories, anything that looks \
    unusual, and one concrete suggestion. Use the currency provided in the JSON. \
    Do not invent numbers. Keep the whole response under 120 words.
    """

    func generate(from summary: SpendingSummary) async {
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

        state = .generating("")

        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let stream = session.streamResponse(to: prompt)
            var latest = ""
            for try await partial in stream {
                latest = partial.content
                state = .generating(latest)
            }
            state = .ready(latest)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
