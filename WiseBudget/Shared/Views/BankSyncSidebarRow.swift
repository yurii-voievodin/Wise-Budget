import SwiftUI
import SwiftData

/// Sync action and inline progress in the sidebar, sitting just below the
/// "Bank Connections" row. Hidden when no bank token exists.
struct BankSyncSidebarRow: View {
    @Bindable var syncService: BankSyncService
    let monthFilter: MonthFilter
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if syncService.hasBankToken {
            VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                syncButton

                if let progress = syncService.progress {
                    progressStrip(for: progress)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: syncService.progress)
        }
    }

    private var syncButton: some View {
        Button(action: triggerSync) {
            HStack(spacing: Layout.Spacing.small) {
                if syncService.isSyncing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 16)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .frame(width: 16)
                }
                Text(syncService.isSyncing ? "Syncing…" : "Sync \(monthLabel)")
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(syncService.isSyncing || syncService.isSyncCooldown || monthFilter.isFutureMonth)
        .help(helpText)
    }

    @ViewBuilder
    private func progressStrip(for progress: SyncProgress) -> some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.tight) {
            Text("\(progress.bank) — \(progress.detail)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            switch progress.kind {
            case .determinate(let current, let total) where total > 0:
                ProgressView(value: Double(current), total: Double(total))
            default:
                ProgressView()
            }
        }
    }

    private var monthLabel: String {
        MonthKey(year: monthFilter.year, month: monthFilter.month).fullLabel
    }

    private var helpText: String {
        if monthFilter.isFutureMonth {
            return "Pick a current or past month to sync"
        }
        if syncService.isSyncCooldown {
            return "Sync available after 1 minute cooldown"
        }
        return "Sync bank transactions for \(monthLabel)"
    }

    private func triggerSync() {
        syncService.sync(
            context: modelContext,
            from: monthFilter.startOfMonth,
            to: monthFilter.startOfNextMonth
        )
    }
}
