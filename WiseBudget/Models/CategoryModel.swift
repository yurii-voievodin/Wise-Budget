import SwiftData

protocol CategoryModel: PersistentModel {
    var name: String { get set }
    var displayIconName: String { get }
    init(name: String)

    /// Re-points every transaction owned by `self` onto `target`, then deletes `self`.
    /// Caller is responsible for saving the context.
    func merge(into target: Self, in context: ModelContext)
}

extension ExpenseCategory: CategoryModel {
    convenience init(name: String) {
        self.init(name: name, iconName: "folder")
    }

    func merge(into target: ExpenseCategory, in context: ModelContext) {
        for expense in expenses {
            expense.category = target
        }
        context.delete(self)
    }
}

extension IncomeCategory: CategoryModel {
    convenience init(name: String) {
        self.init(name: name, iconName: "folder")
    }

    func merge(into target: IncomeCategory, in context: ModelContext) {
        for income in incomes {
            income.category = target
        }
        context.delete(self)
    }
}
