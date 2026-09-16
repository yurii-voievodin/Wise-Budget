import SwiftUI

struct CurrencySearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: Layout.Spacing.snug) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search currency", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill", action: clear)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Layout.Spacing.medium)
        .padding(.vertical, 9)
    }

    private func clear() {
        searchText = ""
    }
}
