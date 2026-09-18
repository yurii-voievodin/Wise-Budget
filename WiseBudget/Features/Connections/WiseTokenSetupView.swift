import SwiftUI

struct WiseTokenSetupView: View {
    @Binding var token: String

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.large) {
            VStack(alignment: .leading, spacing: Layout.Spacing.snug) {
                Label("Step 1", systemImage: "1.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Open Wise settings and create an API token with read-only access.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Open wise.com", action: openWiseSettings)
                    .buttonStyle(.link)
            }

            Divider()

            VStack(alignment: .leading, spacing: Layout.Spacing.snug) {
                Label("Step 2", systemImage: "2.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Copy your personal API token and paste it below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SecureField("Paste your API token here", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func openWiseSettings() {
        if let url = URL(string: "https://wise.com/settings/") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    @Previewable @State var token = ""
    WiseTokenSetupView(token: $token)
        .padding()
        .frame(width: 420)
}
