import Foundation
import SwiftData

@Model
final class BudgetPlan {
    var year: Int
    var month: Int
    var currency: String?
    var monthlyBudget: Decimal?

    @Relationship(deleteRule: .cascade, inverse: \BudgetPlanItem.plan)
    var items: [BudgetPlanItem] = []

    init(year: Int, month: Int, currency: String? = nil, monthlyBudget: Decimal = 0) {
        self.year = year
        self.month = month
        self.currency = currency
        self.monthlyBudget = monthlyBudget
    }

    /// The first day of this plan's month
    var startOfMonth: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1))!
    }

    /// The first day of the next month (exclusive upper bound)
    var startOfNextMonth: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)!
    }

    /// Display label like "March 2026"
    var displayTitle: String {
        startOfMonth.formatted(.dateTime.month(.wide).year())
    }
}
