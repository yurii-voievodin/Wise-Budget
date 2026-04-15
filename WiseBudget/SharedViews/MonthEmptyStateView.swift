import SwiftUI
import SwiftData

struct MonthEmptyStateView: View {
    @Environment(\.modelContext) private var modelContext

    let title: String
    let systemImage: String
    let filter: MonthFilter
    @Bindable var syncService: BankSyncService

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            if filter.isFutureMonth {
                Text("This month hasn't started yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if syncService.hasBankToken {
                if syncService.isSyncing {
                    ProgressView("Syncing...")
                } else if syncService.isSyncCooldown {
                    Text("Sync recently completed. Try again shortly.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Sync your bank to import transactions for this month.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        syncService.sync(context: modelContext, from: filter.startOfMonth, to: filter.startOfNextMonth)
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("No transactions recorded for this month.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty State - No Bank") {
    MonthEmptyStateView(
        title: "No Expenses This Month",
        systemImage: "creditcard",
        filter: MonthFilter(year: 2026, month: 4),
        syncService: BankSyncService()
    )
    .modelContainer(for: [Expense.self], inMemory: true)
    .frame(width: 500, height: 400)
}
