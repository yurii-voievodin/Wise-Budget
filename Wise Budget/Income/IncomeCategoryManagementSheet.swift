import SwiftUI
import SwiftData

struct IncomeCategoryManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

    @State private var newCategoryName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories) { category in
                    @Bindable var category = category
                    TextField("Category name", text: $category.name)
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
            .navigationTitle("Income Categories")
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
        modelContext.insert(IncomeCategory(name: name))
        newCategoryName = ""
    }

    private func deleteCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
