import Foundation
import SwiftData

@Model
final nonisolated class BudgetPlanItem {
    var plannedAmount: Decimal
    var plan: BudgetPlan?
    @Relationship(deleteRule: .nullify) var category: ExpenseCategory?

    init(plannedAmount: Decimal, plan: BudgetPlan? = nil, category: ExpenseCategory? = nil) {
        self.plannedAmount = plannedAmount
        self.plan = plan
        self.category = category
    }
}
