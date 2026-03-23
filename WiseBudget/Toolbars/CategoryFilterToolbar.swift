import SwiftUI

struct CategoryFilterToolbar: ToolbarContent {
    @Binding var selectedCategoryName: String?
    let categories: [(name: String, iconName: String)]

    var body: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button {
                    selectedCategoryName = nil
                } label: {
                    if selectedCategoryName == nil {
                        Label("All Categories", systemImage: "checkmark")
                    } else {
                        Text("All Categories")
                    }
                }
                Divider()
                ForEach(categories, id: \.name) { category in
                    Button {
                        selectedCategoryName = category.name
                    } label: {
                        if selectedCategoryName == category.name {
                            Label(category.name, systemImage: "checkmark")
                        } else {
                            Label(category.name, systemImage: category.iconName)
                        }
                    }
                }
            } label: {
                Label("Category", systemImage: "tag\(selectedCategoryName != nil ? ".fill" : "")")
            }
        }
    }
}
