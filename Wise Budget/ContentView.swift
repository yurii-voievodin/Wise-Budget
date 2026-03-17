import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .expenses

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ItemListView(category: selectedSidebarItem.itemCategory)
                .id(selectedSidebarItem)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
