import SwiftUI

struct BulkCategoryMenu<C: CategoryModel>: View {
    let categories: [C]
    let onSelect: (C?) -> Void

    var body: some View {
        Menu("Change Category") {
            ForEach(categories) { category in
                Button {
                    onSelect(category)
                } label: {
                    Label(category.name, systemImage: category.displayIconName)
                }
            }
            Divider()
            Button("No Category") {
                onSelect(nil)
            }
        }
    }
}
