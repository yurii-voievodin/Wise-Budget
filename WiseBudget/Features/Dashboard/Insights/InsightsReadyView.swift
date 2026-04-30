import SwiftUI

struct InsightsReadyView: View {
    let hints: [String]

    var body: some View {
        InsightHintsList(hints: hints)
    }
}
