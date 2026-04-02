import SwiftUI
import SwiftData

struct CategorySettingsContent<C: CategoryModel>: View {
    @Environment(\.modelContext) private var modelContext

    let categories: [C]

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
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(categories[index])
                }
            }

            HStack {
                TextField("New category", text: $newCategoryName)
                Button("Add") {
                    let name = newCategoryName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    modelContext.insert(C(name: name))
                    newCategoryName = ""
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
