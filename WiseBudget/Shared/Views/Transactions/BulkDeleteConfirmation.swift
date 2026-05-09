import SwiftData
import SwiftUI

extension View {
    func bulkDeleteConfirmation<Item: PersistentModel>(
        items: Binding<[Item]>,
        singularNoun: String,
        pluralNoun: String,
        onConfirm: @escaping ([Item]) -> Void
    ) -> some View {
        modifier(BulkDeleteConfirmation(items: items, singularNoun: singularNoun, pluralNoun: pluralNoun, onConfirm: onConfirm))
    }
}

private struct BulkDeleteConfirmation<Item: PersistentModel>: ViewModifier {
    @Binding var items: [Item]
    let singularNoun: String
    let pluralNoun: String
    let onConfirm: ([Item]) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            items.count == 1 ? "Delete this \(singularNoun)?" : "Delete \(items.count) \(pluralNoun)?",
            isPresented: Binding(
                get: { !items.isEmpty },
                set: { if !$0 { items = [] } }
            ),
            titleVisibility: .visible,
            presenting: items
        ) { snapshot in
            Button("Delete", role: .destructive) {
                onConfirm(snapshot)
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This cannot be undone.")
        }
    }
}
