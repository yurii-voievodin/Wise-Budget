import SwiftUI

/// Compact label + amount tile used for KPI grids on the Dashboard and the
/// Budget Plan summary. Caller controls the color, weight, and sign affordances.
struct StatCard: View {
    let label: LocalizedStringKey
    let icon: String
    let color: Color
    let amount: Decimal
    let currency: String
    var signed: Bool = false
    var bold: Bool = false
    var precision: Int = 2
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.snug) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .lineLimit(1)
            Text(amount: amount, currency: currency, signed: signed, precision: precision)
                .font(.title3)
                .monospacedDigit()
                .bold(bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
