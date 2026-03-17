import SwiftUI
import SwiftData

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    let category: ItemCategory

    init(category: ItemCategory) {
        self.category = category
        _items = Query(
            filter: #Predicate<Item> { item in
                item.category == category
            },
            sort: \.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        List {
            ForEach(items) { item in
                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle(category == .expense ? "Expenses" : "Income")
        .toolbar {
            ToolbarItem {
                Button(action: addItem) {
                    Label("Add Item", systemImage: "plus")
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date(), category: category)
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}
