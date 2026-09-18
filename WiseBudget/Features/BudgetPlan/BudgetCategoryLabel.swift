import SwiftUI

struct BudgetCategoryLabel: View {
    let categoryName: String
    let categoryIcon: String

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            CategoryIconBadge(
                systemName: categoryIcon,
                color: DefaultExpenseCategory.color(for: categoryName),
                size: 24
            )
            Text(categoryName)
        }
    }
}
