import SwiftUI

struct TransactionCategoryMenu<C: CategoryModel & Hashable>: View {
    let categories: [C]
    @Binding var selectedCategory: C?

    var body: some View {
        Menu {
            Button("None", action: clearSelection)
            Divider()
            ForEach(categories) { category in
                Button {
                    selectedCategory = category
                } label: {
                    Label(category.name, systemImage: category.displayIconName)
                }
            }
        } label: {
            HStack(spacing: Layout.Spacing.small) {
                if let selectedCategory {
                    CategoryIconBadge(
                        systemName: selectedCategory.displayIconName,
                        color: C.badgeColor(for: selectedCategory.name),
                        size: 22
                    )
                    Text(selectedCategory.name)
                } else {
                    CategoryIconBadge(systemName: "tray", color: .secondary, size: 22)
                    Text("None")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Category")
        .accessibilityValue(selectedCategory?.name ?? "None")
    }

    private func clearSelection() {
        selectedCategory = nil
    }
}
