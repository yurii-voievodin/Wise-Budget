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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .lineLimit(1)
            Text(amount: amount, currency: currency, signed: signed)
                .font(.title3)
                .monospacedDigit()
                .bold(bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
