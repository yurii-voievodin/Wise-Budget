import Foundation

struct ExpenseFilter: Hashable {
    var year: Int
    var month: Int
    var foreignOnly: Bool = false
    var planCurrency: String? = nil
}
