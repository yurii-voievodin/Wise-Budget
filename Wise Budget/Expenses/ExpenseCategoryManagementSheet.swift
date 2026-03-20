import SwiftUI
import SwiftData

struct ExpenseCategoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Expense Categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 350, minHeight: 300)
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
