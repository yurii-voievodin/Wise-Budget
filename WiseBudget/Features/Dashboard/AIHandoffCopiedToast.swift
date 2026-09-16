import SwiftUI

struct AIHandoffCopiedToast: View {
    let provider: AIProvider

    var body: some View {
        Label("Copied — paste in \(provider.displayName) with ⌘V", systemImage: "doc.on.clipboard")
            .font(.callout)
            .padding(.horizontal, Layout.Spacing.large)
            .padding(.vertical, Layout.Spacing.medium)
            .background(.thinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.separator, lineWidth: 0.5) }
            .shadow(radius: 6, y: 2)
    }
}
