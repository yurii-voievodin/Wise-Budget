import Foundation
import SwiftData

enum WiseBudgetMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WiseBudgetSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
