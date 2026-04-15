import SwiftData

enum WiseBudgetSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Expense.self,
            Income.self,
            ExpenseCategory.self,
            IncomeCategory.self,
            BudgetPlan.self,
            BudgetPlanItem.self,
        ]
    }
}

enum WiseBudgetMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WiseBudgetSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
