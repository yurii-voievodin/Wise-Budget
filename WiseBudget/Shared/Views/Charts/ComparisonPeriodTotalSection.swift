import SwiftUI

struct ComparisonPeriodTotalSection: View {
    let total: Double
    let currency: String

    var body: some View {
        Section("Period Total") {
            LabeledContent("Total") {
                Text(amount: Decimal(total), currency: currency, precision: 0)
                    .monospacedDigit()
                    .bold()
            }
        }
    }
}
