import SwiftData

enum WiseBudgetSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Expense.self,
            Income.self,
            ExpenseCategory.self,
            IncomeCategory.self,
            BudgetPlan.self,
            BudgetPlanItem.self,
            CachedInsight.self,
        ]
    }
}
