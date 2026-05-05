import SwiftUI
import SwiftData

extension FocusedValues {
    @Entry var selectedMonthFilter: MonthFilter? = nil
}

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    @State private var monthFilter: MonthFilter = .stored
    @State private var expenseCategoryFilter: String?
    @State private var expenseListTab: ExpenseListView.ExpenseTab = .calendar
    @State private var syncService = BankSyncService()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Overview") {
                    ForEach([SidebarItem.dashboard, .budgetPlan, .expenses, .income, .cashflow, .lifetime], id: \.self) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SidebarBottomSection(
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService,
                    monthFilter: monthFilter
                )
            }
        } detail: {
            switch selectedSidebarItem {
            case .dashboard:
                DashboardView(
                    monthFilter: $monthFilter,
                    onSelectCategory: { categoryName in
                        expenseCategoryFilter = categoryName
                        expenseListTab = .expenses
                        selectedSidebarItem = .expenses
                    },
                    onAddExpense: {
                        expenseCategoryFilter = nil
                        expenseListTab = .expenses
                        selectedSidebarItem = .expenses
                    },
                    onConnectBank: {
                        selectedSidebarItem = .bankConnections
                    }
                )
                .id(monthFilter)
                .toolbar {
                    MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                }
            case .budgetPlan:
                BudgetPlanView(selectedSidebarItem: $selectedSidebarItem, monthFilter: $monthFilter, expenseCategoryFilter: $expenseCategoryFilter)
            case .expenses:
                ExpenseListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem, selectedCategoryName: $expenseCategoryFilter, selectedTab: $expenseListTab, syncService: syncService)
            case .income:
                IncomeListView(filter: $monthFilter, selectedSidebarItem: $selectedSidebarItem, syncService: syncService)
            case .cashflow:
                CashflowView(filter: monthFilter)
                    .toolbar {
                        MonthNavigationToolbar(year: $monthFilter.year, month: $monthFilter.month)
                    }
            case .lifetime:
                LifetimeView()
            case .bankConnections:
                BankConnectionsView()
            }
        }
        .focusedSceneValue(\.selectedMonthFilter, monthFilter)
        .onChange(of: monthFilter) { _, newValue in
            newValue.persist()
        }
        .onChange(of: selectedSidebarItem) { oldValue, newValue in
            if oldValue == .expenses || oldValue == .income {
                monthFilter.foreignOnly = false
            }
            if oldValue == .expenses {
                expenseCategoryFilter = nil
                expenseListTab = .calendar
            }
        }
    }
}

private struct SidebarBottomSection: View {
    @Binding var selectedSidebarItem: SidebarItem
    @Bindable var syncService: BankSyncService
    let monthFilter: MonthFilter

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                BankSyncSidebarRow(syncService: syncService, monthFilter: monthFilter)
                    .padding(.horizontal, 8)

                Button {
                    selectedSidebarItem = .bankConnections
                } label: {
                    Label(SidebarItem.bankConnections.rawValue, systemImage: SidebarItem.bankConnections.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            isBankConnectionsSelected ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .foregroundStyle(isBankConnectionsSelected ? Color.white : Color.primary)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
        }
    }

    private var isBankConnectionsSelected: Bool {
        selectedSidebarItem == .bankConnections
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewSampleData.container)
}
