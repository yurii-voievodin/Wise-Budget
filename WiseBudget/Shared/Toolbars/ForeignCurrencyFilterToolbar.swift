import SwiftUI

struct TransactionFilterToolbar: ToolbarContent {
    @Binding var foreignOnly: Bool
    @Binding var sourceFilter: TransactionSourceFilter

    private var anyFilterActive: Bool {
        foreignOnly || sourceFilter != .all
    }

    var body: some ToolbarContent {
        ToolbarItem {
            Menu {
                Section("Currency") {
                    Button {
                        foreignOnly = false
                    } label: {
                        if !foreignOnly {
                            Label("All currencies", systemImage: "checkmark")
                        } else {
                            Text("All currencies")
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
                }
                Section("Source") {
                    sourceButton(.all, label: "All sources")
                    sourceButton(.syncedOnly, label: "Synced only")
                    sourceButton(.manualOnly, label: "Manual / CSV only")
                }
            } label: {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle\(anyFilterActive ? ".fill" : "")")
            }
        }
    }

    private func sourceButton(_ value: TransactionSourceFilter, label: String) -> some View {
        Button {
            sourceFilter = value
        } label: {
            if sourceFilter == value {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }
}
