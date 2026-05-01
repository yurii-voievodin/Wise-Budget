import Foundation

extension Dictionary where Key == String, Value == Decimal {
    func sortedWithDefaultFirst(_ defaultCurrency: String) -> [(key: String, value: Decimal)] {
        sorted { a, b in
            if a.key == defaultCurrency { return true }
            if b.key == defaultCurrency { return false }
            return a.key < b.key
        }
    }
}

func formattedCalendarAmount(_ value: Decimal) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
}
