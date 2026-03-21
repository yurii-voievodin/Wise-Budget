import SwiftUI

/// Toolbar button that syncs all connected banks for the selected month.
/// Only visible when a bank token exists and the selected month is not in the future.
struct BankSyncToolbar: ToolbarContent {
    @Bindable var syncService: BankSyncService
    let filter: MonthFilter

    private var isFutureMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let currentYear = now.year ?? 0
        let currentMonth = now.month ?? 0
        return filter.year > currentYear || (filter.year == currentYear && filter.month > currentMonth)
    }

    var body: some ToolbarContent {
        if syncService.hasBankToken && !isFutureMonth {
            ToolbarItem {
                Button(action: { syncService.sync(context: context, from: filter.startOfMonth) }) {
                    if syncService.isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sync Banks", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(syncService.isSyncing || syncService.isSyncCooldown)
                .help(syncService.isSyncCooldown ? "Sync available after 1 minute cooldown" : "Sync bank transactions for this month")
            }
        }
    }

    @Environment(\.modelContext) private var context
}
