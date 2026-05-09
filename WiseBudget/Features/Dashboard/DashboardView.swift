import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var incomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback
    @AppStorage("monobankConnectedName") private var monobankConnectedName: String = ""
    @AppStorage("wiseConnectedName") private var wiseConnectedName: String = ""

    @Binding var monthFilter: MonthFilter
    var onSelectCategory: (String) -> Void
    var onAddExpense: () -> Void
    var onConnectBank: () -> Void

    @State private var expenseToEdit: Expense?
    @State private var incomeToEdit: Income?
    @State private var askAIToastProvider: AIProvider?
    @State private var askAIToastTask: Task<Void, Never>?
    @State private var hasAnyExpenses = true
    @State private var hasAnyIncomes = true
    @State private var hasKeychainTokens = false
    @State private var showByCategoryPopover = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        monthFilter: Binding<MonthFilter>,
        onSelectCategory: @escaping (String) -> Void = { _ in },
        onAddExpense: @escaping () -> Void = {},
        onConnectBank: @escaping () -> Void = {}
    ) {
        self._monthFilter = monthFilter
        self.onSelectCategory = onSelectCategory
        self.onAddExpense = onAddExpense
        self.onConnectBank = onConnectBank

        let startDate = monthFilter.wrappedValue.startOfMonth
        let endDate = monthFilter.wrappedValue.startOfNextMonth
        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate && !expense.isInternalTransfer
            },
            sort: \.date,
            order: .reverse
        )

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate && !income.isInternalTransfer
            },
            sort: \.date,
            order: .reverse
        )
    }

    // MARK: - Computed

    private var metrics: DashboardMetrics {
        DashboardMetrics(
            monthFilter: monthFilter,
            totalIncome: incomes.reduce(.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) },
            totalExpenses: expenses.reduce(.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
        )
    }

    private var expenseSlices: [CategoryChartSlice] {
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        return grouped.map { name, items in
            let sum = items.reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
            let icon = items.first?.category?.displayIconName ?? "folder"
            return CategoryChartSlice(name: name, iconName: icon, total: NSDecimalNumber(decimal: sum).doubleValue)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    private var spendingSummary: SpendingSummary {
        SpendingSummary.build(
            monthFilter: monthFilter,
            currency: defaultCurrency,
            expenses: expenses,
            incomes: incomes
        )
    }

    private var insightsScopeKey: String {
        MonthScopeKey.make(year: monthFilter.year, month: monthFilter.month)
    }

    private var recentTransactions: [DashboardRecentTransaction] {
        let expenseItems = expenses.prefix(5).map {
            DashboardRecentTransaction(
                id: $0.persistentModelID,
                descriptionText: $0.descriptionText,
                categoryName: $0.category?.name,
                categoryIcon: $0.category?.displayIconName,
                item: $0,
                isExpense: true,
                date: $0.date
            )
        }
        let incomeItems = incomes.prefix(5).map {
            DashboardRecentTransaction(
                id: $0.persistentModelID,
                descriptionText: $0.descriptionText,
                categoryName: $0.category?.name,
                categoryIcon: $0.category?.displayIconName,
                item: $0,
                isExpense: false,
                date: $0.date
            )
        }
        return Array(
            (expenseItems + incomeItems)
                .sorted { $0.date > $1.date }
                .prefix(5)
        )
    }

    private var isFirstLaunchEmptyState: Bool {
        !hasAnyExpenses && !hasAnyIncomes && !hasConnectedBank
    }

    private var hasConnectedBank: Bool {
        !monobankConnectedName.isEmpty || !wiseConnectedName.isEmpty || hasKeychainTokens
    }

    private var isCurrentMonthEmpty: Bool {
        expenses.isEmpty && incomes.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isCurrentMonthEmpty {
                emptyStateView
            } else {
                dashboardContentView
            }
        }
        .onAppear { checkForAnyTransactions() }
    }

    private var emptyStateView: some View {
        DashboardEmptyStateView(
            state: isFirstLaunchEmptyState ? .onboarding : .noTransactionsThisMonth,
            onAddExpense: onAddExpense,
            onConnectBank: onConnectBank
        )
    }

    private var dashboardContentView: some View {
        DashboardOverviewTab(
            summary: spendingSummary,
            metrics: metrics,
            scopeKey: insightsScopeKey,
            currency: defaultCurrency,
            recentTransactions: recentTransactions,
            onSelectTransaction: handleTransactionSelection
        )
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(expense: expense) { result in
                withAnimation { result.apply(to: expense) }
            }
        }
        .sheet(item: $incomeToEdit) { income in
            IncomeFormSheet(income: income) { result in
                withAnimation { result.apply(to: income) }
            }
        }
        .overlay(alignment: .bottom) {
            if let provider = askAIToastProvider {
                AIHandoffCopiedToast(provider: provider)
                    .padding(.bottom, 24)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showByCategoryPopover.toggle()
                } label: {
                    Label("By Category", systemImage: "chart.pie")
                }
                .help("By Category")
                .popover(isPresented: $showByCategoryPopover, arrowEdge: .top) {
                    DashboardByCategoryTab(
                        expenseSlices: expenseSlices,
                        currency: defaultCurrency,
                        onSelectCategory: { name in
                            showByCategoryPopover = false
                            onSelectCategory(name)
                        }
                    )
                    .frame(minWidth: 420, minHeight: 480)
                }
            }
            AskAIToolbar(
                filter: monthFilter,
                expenseCount: expenses.count,
                onCopied: presentAskAIToast
            )
        }
    }

    private func handleTransactionSelection(_ transaction: DashboardRecentTransaction) {
        if let expense = transaction.item as? Expense {
            expenseToEdit = expense
        } else if let income = transaction.item as? Income {
            incomeToEdit = income
        }
    }

    private func checkForAnyTransactions() {
        hasAnyExpenses = ((try? modelContext.fetchCount(FetchDescriptor<Expense>())) ?? 0) > 0
        hasAnyIncomes = ((try? modelContext.fetchCount(FetchDescriptor<Income>())) ?? 0) > 0
        hasKeychainTokens =
            KeychainHelper.loadToken(service: KeychainHelper.monobankService) != nil
            || KeychainHelper.loadToken(service: KeychainHelper.wiseService) != nil
    }

    private func presentAskAIToast(provider: AIProvider) {
        askAIToastTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            askAIToastProvider = provider
        }
        askAIToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                askAIToastProvider = nil
            }
        }
    }
}

private struct AIHandoffCopiedToast: View {
    let provider: AIProvider

    var body: some View {
        Label("Copied — paste in \(provider.displayName) with ⌘V", systemImage: "doc.on.clipboard")
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .shadow(radius: 6, y: 2)
    }
}

#Preview {
    @Previewable @State var filter = MonthFilter(year: 2026, month: 3)
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.container)
        .environment(LocalAIAppDetector())
        .frame(width: 600, height: 600)
}

#Preview("Budget Pacing") {
    @Previewable @State var filter = MonthFilter.currentMonth()
    DashboardView(monthFilter: $filter)
        .modelContainer(PreviewSampleData.overspendingPaceContainer)
        .environment(LocalAIAppDetector())
        .frame(width: 600, height: 700)
}
