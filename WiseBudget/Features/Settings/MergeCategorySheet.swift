import SwiftUI
import SwiftData

struct MergeCategorySheet<C: CategoryModel>: View {
    let source: C
    let candidates: [C]
    let onConfirm: (C) -> Void
    let onCancel: () -> Void

    @State private var selectedID: C.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.large) {
            Text("Merge \"\(source.name)\" into…")
                .font(.headline)
            Text("All transactions from \"\(source.name)\" will be moved to the selected category, and \"\(source.name)\" will be deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(candidates, selection: $selectedID) { candidate in
                HStack(spacing: Layout.Spacing.small) {
                    CategoryIconBadge(
                        systemName: candidate.displayIconName,
                        color: C.badgeColor(for: candidate.name),
                        size: 24
                    )
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
        .padding(Layout.Spacing.xLarge)
        .frame(minWidth: 380)
    }
}
