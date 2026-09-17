import SwiftUI
import SwiftData

/// Sync action and inline progress in the sidebar, sitting just below the
/// "Bank Connections" row. Hidden when no bank token exists.
struct BankSyncSidebarRow: View {
    @Bindable var syncService: BankSyncService
    let monthFilter: MonthFilter
    @Environment(\.modelContext) private var modelContext

    @State private var showErrorsPopover = false

    var body: some View {
        if syncService.hasBankToken {
            HStack(spacing: Layout.Spacing.small) {
                syncButton
                if !syncService.isSyncing && !syncService.lastSyncErrors.isEmpty {
                    errorIndicator
                }
            }
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
                Text(syncingLabel)
                Spacer()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(syncService.isSyncing || syncService.isSyncCooldown || monthFilter.isFutureMonth)
        .help(helpText)
    }

    private var errorIndicator: some View {
        Button {
            showErrorsPopover = true
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .help("Sync completed with errors")
        .popover(isPresented: $showErrorsPopover) {
            VStack(alignment: .leading, spacing: Layout.Spacing.small) {
                ForEach(syncService.lastSyncErrors) { failure in
                    Text("\(failure.bank.displayName): \(failure.message)")
                }
            }
            .padding()
            .frame(minWidth: 240, maxWidth: 360)
        }
    }

    private var syncingLabel: String {
        guard syncService.isSyncing else { return "Sync \(monthLabel)" }
        guard let bank = syncService.currentBank else { return "Syncing…" }
        return "Syncing \(bank.displayName)…"
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
