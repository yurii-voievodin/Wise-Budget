import SwiftUI

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, Layout.Spacing.medium)
            .cardBackground(cornerRadius: Layout.Radius.large)
    }
}
