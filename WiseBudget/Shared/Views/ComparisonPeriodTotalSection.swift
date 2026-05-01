import SwiftUI

struct ComparisonPeriodTotalSection: View {
    let total: Double
    let currency: String

    var body: some View {
        Section("Period Total") {
            LabeledContent("Total") {
                Text("\(Decimal(total), format: .number.precision(.fractionLength(0))) \(currency)")
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
        }
    }
}
