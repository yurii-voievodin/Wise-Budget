import SwiftData

protocol CategoryModel: PersistentModel {
    var name: String { get set }
    var displayIconName: String { get }
    init(name: String)
}

extension ExpenseCategory: CategoryModel {
    convenience init(name: String) {
        self.init(name: name, iconName: "folder")
    }
}

extension IncomeCategory: CategoryModel {
    convenience init(name: String) {
        self.init(name: name, iconName: "folder")
    }
}
