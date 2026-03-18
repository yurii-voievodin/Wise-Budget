import Foundation

struct ExpenseFilter: Equatable {
    var year: Int
    var month: Int
    var foreignOnly: Bool = false
    var planCurrency: String? = nil
}
