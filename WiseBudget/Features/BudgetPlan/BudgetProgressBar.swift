import SwiftUI

struct BudgetProgressBar: View {
    let spent: Decimal
    let planned: Decimal

    static func isUnplannedSpending(planned: Decimal, spent: Decimal) -> Bool {
        planned <= 0 && spent > 0
    }

    private var isUnplannedSpending: Bool {
        Self.isUnplannedSpending(planned: planned, spent: spent)
    }

    private var ratio: Double {
        guard planned > 0 else { return 0 }
        return Double(truncating: spent as NSDecimalNumber) / Double(truncating: planned as NSDecimalNumber)
    }

    private var progress: Double {
        isUnplannedSpending ? 1.0 : min(ratio, 1.0)
    }

    private static let thresholdLow = 0.5
    private static let thresholdMedium = 0.75
    private static let thresholdHigh = 1.0

    private var barColor: Color {
        if isUnplannedSpending {
            return .expense
        }
        switch ratio {
        case ...0: return .clear
        case ..<Self.thresholdLow: return .income
        case Self.thresholdLow..<Self.thresholdMedium: return .yellow
        case Self.thresholdMedium..<Self.thresholdHigh: return .orange
        default: return .expense
        }
    }

    private var isOverBudget: Bool { ratio > 1 }

    private var overflowFraction: Double {
        guard isOverBudget else { return 0 }
        return min((ratio - 1) / ratio, 0.6)
    }

    private var fillAnchor: UnitPoint { isOverBudget ? .trailing : .leading }

    private var fillFraction: Double { isOverBudget ? overflowFraction : progress }

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.secondary.opacity(0.15))
            Capsule()
                .fill(barColor.opacity(isOverBudget ? 0.45 : 0))
            Capsule()
                .fill(barColor)
                .scaleEffect(x: fillFraction, anchor: fillAnchor)
        }
        .frame(height: 6)
        .animation(Motion.settle, value: progress)
        .accessibilityElement()
        .accessibilityLabel("Budget progress")
        .accessibilityValue(
            isUnplannedSpending
                ? "No budget planned, \(spent.formatted()) spent"
                : "\(Int(ratio * 100)) percent spent"
        )
    }
}

#Preview("Light") {
    BudgetProgressBarPreviewSamples()
        .frame(width: 400)
}

#Preview("Dark") {
    BudgetProgressBarPreviewSamples()
        .frame(width: 400)
        .preferredColorScheme(.dark)
}

private struct BudgetProgressBarPreviewSamples: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.xLarge) {
            BudgetProgressBar(spent: 200, planned: 500)   // 40%
            BudgetProgressBar(spent: 400, planned: 500)   // 80%
            BudgetProgressBar(spent: 480, planned: 500)   // 96%
            BudgetProgressBar(spent: 500, planned: 500)   // 100%
            BudgetProgressBar(spent: 700, planned: 500)   // 140% over
        }
        .padding()
    }
}
