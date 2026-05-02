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
                    Image(systemName: category.displayIconName)
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
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

private struct MergeCategorySheet<C: CategoryModel>: View {
    let source: C
    let candidates: [C]
    let onConfirm: (C) -> Void
    let onCancel: () -> Void

    @State private var selectedID: C.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Merge \"\(source.name)\" into…")
                .font(.headline)
            Text("All transactions from \"\(source.name)\" will be moved to the selected category, and \"\(source.name)\" will be deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(candidates, selection: $selectedID) { candidate in
                HStack {
                    Image(systemName: candidate.displayIconName)
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    Text(candidate.name)
                }
                .tag(candidate.id as C.ID?)
            }
            .frame(minHeight: 240)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Merge") {
                    if let target = candidates.first(where: { $0.id == selectedID }) {
                        onConfirm(target)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedID == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 380)
    }
}
