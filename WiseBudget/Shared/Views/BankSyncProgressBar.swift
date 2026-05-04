import SwiftUI

struct BankSyncProgressBar: View {
    @Bindable var syncService: BankSyncService

    var body: some View {
        Group {
            if let progress = syncService.progress {
                strip(for: progress)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.default, value: syncService.progress)
    }

    @ViewBuilder
    private func strip(for progress: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(progress.bank) — \(progress.detail)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if case .determinate(let current, let total) = progress.kind {
                    Text("\(current) / \(total)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            switch progress.kind {
            case .determinate(let current, let total) where total > 0:
                ProgressView(value: Double(current), total: Double(total))
            default:
                ProgressView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
    }
}
