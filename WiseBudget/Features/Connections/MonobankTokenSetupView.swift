import SwiftUI

struct MonobankTokenSetupView: View {
    @Binding var token: String

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.large) {
            VStack(alignment: .leading, spacing: Layout.Spacing.snug) {
                Label("Step 1", systemImage: "1.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Open the Monobank API portal and log in with your phone number.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Button("Open api.monobank.ua", action: openMonobankPortal)
                    .buttonStyle(.link)
            }

            Divider()

            VStack(alignment: .leading, spacing: Layout.Spacing.snug) {
                Label("Step 2", systemImage: "2.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Copy your personal token and paste it below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                SecureField("Paste your API token here", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func openMonobankPortal() {
        if let url = URL(string: "https://api.monobank.ua/") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    @Previewable @State var token = ""
    MonobankTokenSetupView(token: $token)
        .padding()
        .frame(width: 420)
}
