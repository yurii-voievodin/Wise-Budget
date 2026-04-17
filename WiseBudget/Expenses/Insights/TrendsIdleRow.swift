import SwiftUI

struct TrendsIdleRow: View {
    let isEmpty: Bool
    let onGenerate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Label("On-device AI analysis of month-over-month dynamics.", systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            Button("Analyze", action: onGenerate)
                .disabled(isEmpty)
        }
    }
}
