import SwiftUI

extension Text {
    init(amount: Decimal, currency: String, signed: Bool = false) {
        let prefix = signed && amount >= .zero ? "+" : ""
        self.init("\(prefix)\(amount, format: .number.precision(.fractionLength(2))) \(currency)")
    }
}
