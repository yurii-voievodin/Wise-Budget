import SwiftUI
import SwiftData

struct ExpenseCategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""

    var body: some View {
        List {
            ForEach(categories) { category in
                @Bindable var category = category
                HStack {
                    Image(systemName: category.displayIconName)
                        .frame(width: 20)
                        .foregroundStyle(.secondary)
                    TextField("Category name", text: $category.name)
                }
            }
            .onDelete(perform: deleteCategory)

            HStack {
                TextField("New category", text: $newCategoryName)
                Button("Add") {
                    addCategory()
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.insert(ExpenseCategory(name: name))
        newCategoryName = ""
    }

    private func deleteCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
