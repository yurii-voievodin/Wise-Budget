import SwiftUI

extension Text {
    init(amount: Decimal, currency: String, signed: Bool = false, precision: Int = 2) {
        let prefix = signed && amount >= .zero ? "+" : ""
        self.init("\(prefix)\(amount, format: .number.precision(.fractionLength(precision))) \(currency)")
    }
}
