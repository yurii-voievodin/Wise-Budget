import SwiftUI

struct FormRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: Layout.Spacing.medium) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(minWidth: 96, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }
}
