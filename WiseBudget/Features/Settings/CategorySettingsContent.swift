import SwiftUI
import SwiftData

struct CategorySettingsContent<C: CategoryModel>: View {
    @Environment(\.modelContext) private var modelContext

    let categories: [C]

    @State private var newCategoryName = ""
    @State private var mergeSource: C?

    var body: some View {
        List {
            ForEach(categories) { category in
                @Bindable var category = category
                HStack {
                    CategoryIconBadge(
                        systemName: category.displayIconName,
                        color: C.badgeColor(for: category.name),
                        size: 28
                    )
                    TextField("Category name", text: $category.name)
                    Menu {
                        Button("Merge into…") { mergeSource = category }
                            .disabled(categories.count < 2)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .frame(minHeight: 28)
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
        .sheet(item: $mergeSource) { source in
            MergeCategorySheet(source: source, candidates: categories.filter { $0.id != source.id }) { target in
                source.merge(into: target, in: modelContext)
                mergeSource = nil
            } onCancel: {
                mergeSource = nil
            }
        }
    }
}
