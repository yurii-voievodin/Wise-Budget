import Foundation

struct MonthlyTotals: Identifiable {
    let month: MonthKey
    let income: Decimal
    let expenses: Decimal

    var id: MonthKey { month }
    var balance: Decimal { income - expenses }
    var hasActivity: Bool { income > 0 || expenses > 0 }
}
