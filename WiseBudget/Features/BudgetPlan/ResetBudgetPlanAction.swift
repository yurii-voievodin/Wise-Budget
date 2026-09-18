import SwiftUI

struct ResetBudgetPlanAction: Equatable {
    private let perform: () -> Void

    init(_ perform: @escaping () -> Void) {
        self.perform = perform
    }

    func callAsFunction() {
        perform()
    }

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}
