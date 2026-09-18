import SwiftUI

struct WiseProfileRow: View {
    let profile: WiseProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text("\(profile.fullName) (\(profile.type.capitalized))")
                    .font(.callout)
                Spacer()
            }
            .padding(.vertical, Layout.Spacing.tight)
            .padding(.horizontal, Layout.Spacing.small)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(.rect(cornerRadius: Layout.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
