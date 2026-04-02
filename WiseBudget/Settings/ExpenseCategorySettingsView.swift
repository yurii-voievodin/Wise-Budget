import SwiftUI
import SwiftData

struct ExpenseCategorySettingsView: View {
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    var body: some View {
        CategorySettingsContent(categories: categories)
    }
}
