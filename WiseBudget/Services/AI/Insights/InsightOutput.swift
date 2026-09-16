import Foundation
import FoundationModels

/// File-scope (not nested) and short `@Guide` text are deliberate per Apple
/// TN3193 — long descriptions inflate context size and add latency.
@Generable
struct InsightOutput: Equatable {
    @Guide(description: "Up to three short hints about the month's spending.")
    let hints: [String]
}
