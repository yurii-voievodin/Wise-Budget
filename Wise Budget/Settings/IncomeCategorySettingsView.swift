import SwiftUI
import SwiftData

struct IncomeCategorySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]

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
        modelContext.insert(IncomeCategory(name: name))
        newCategoryName = ""
    }

    private func deleteCategory(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
    }
}
