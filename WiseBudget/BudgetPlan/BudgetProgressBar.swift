import SwiftUI

struct BudgetProgressBar: View {
    let spent: Decimal
    let planned: Decimal

    private var ratio: Double {
        guard planned > 0 else { return 0 }
        return Double(truncating: spent as NSDecimalNumber) / Double(truncating: planned as NSDecimalNumber)
    }

    private var progress: Double {
        min(ratio, 1.0)
    }

    private static let thresholdLow = 0.5
    private static let thresholdMedium = 0.75
    private static let thresholdHigh = 1.0

    private var barColor: Color {
        switch ratio {
        case ..<Self.thresholdLow:
            return .green
        case Self.thresholdLow..<Self.thresholdMedium:
            return .yellow
        case Self.thresholdMedium...Self.thresholdHigh:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: geo.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}
