import SwiftUI

struct WiseProfileSelectionView: View {
    let connectedName: String
    let profiles: [WiseProfile]
    @Binding var selectedProfile: WiseProfile?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Connected as \(connectedName)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)

            if profiles.count > 1 {
                Divider()

                Text("Select profile to sync")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(profiles) { profile in
                    WiseProfileRow(
                        profile: profile,
                        isSelected: selectedProfile?.id == profile.id,
                        onSelect: { selectedProfile = profile }
                    )
                }
            }

            Divider()

            Text("Transfers for this profile will be synced automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

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
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .clipShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
