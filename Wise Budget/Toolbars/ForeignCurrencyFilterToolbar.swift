import SwiftUI

struct ForeignCurrencyFilterToolbar: ToolbarContent {
    @Binding var foreignOnly: Bool

    var body: some ToolbarContent {
        ToolbarItem {
            Menu {
                Button {
                    foreignOnly = false
                } label: {
                    if !foreignOnly {
                        Label("None", systemImage: "checkmark")
                    } else {
                        Text("None")
                    }
                }
                Button {
                    foreignOnly = true
                } label: {
                    if foreignOnly {
                        Label("Foreign currency", systemImage: "checkmark")
                    } else {
                        Text("Foreign currency")
                    }
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle\(foreignOnly ? ".fill" : "")")
            }
        }
    }
}
