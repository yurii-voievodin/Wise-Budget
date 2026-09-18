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
