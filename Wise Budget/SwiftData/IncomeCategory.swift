import Foundation
import SwiftData

@Model
final class IncomeCategory {
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Income.category)
    var incomes: [Income] = []

    init(name: String) {
        self.name = name
    }
}
