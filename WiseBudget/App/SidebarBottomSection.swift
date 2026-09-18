import SwiftUI

struct SidebarBottomSection: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService
    let monthFilter: MonthFilter

    private var isBankConnectionsSelected: Bool {
        selectedSidebarItem == .bankConnections
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: Layout.Spacing.medium) {
                BankSyncSidebarRow(syncService: syncService, monthFilter: monthFilter)
                    .padding(.horizontal, Layout.Spacing.small)

                Button(action: showBankConnections) {
                    Label(SidebarItem.bankConnections.rawValue, systemImage: SidebarItem.bankConnections.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Layout.Spacing.small)
                        .padding(.vertical, Layout.Spacing.snug)
                        .background(
                            isBankConnectionsSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                            in: RoundedRectangle(cornerRadius: Layout.Radius.small)
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isBankConnectionsSelected ? [.isButton, .isSelected] : .isButton)
            }
            .padding(Layout.Spacing.small)
        }
    }

    private func showBankConnections() {
        selectedSidebarItem = .bankConnections
    }
}
