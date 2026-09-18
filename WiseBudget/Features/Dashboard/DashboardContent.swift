import SwiftUI

struct DashboardContent: View {
    let summary: SpendingSummary
    let metrics: DashboardMetrics
    let scopeKey: String
    let currency: String
    let recentTransactions: [DashboardRecentTransaction]
    let expenseSlices: [CategoryChartSlice]
    let monthFilter: MonthFilter
    let expenseCount: Int
    let onSelectCategory: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var expenseToEdit: Expense?
    @State private var incomeToEdit: Income?
    @State private var askAIToastProvider: AIProvider?
    @State private var askAIToastTask: Task<Void, Never>?

    var body: some View {
        DashboardOverviewTab(
            summary: summary,
            metrics: metrics,
            scopeKey: scopeKey,
            currency: currency,
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
            if let askAIToastProvider {
                AIHandoffCopiedToast(provider: askAIToastProvider)
                    .padding(.bottom, 24)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DashboardByCategoryButton(
                    expenseSlices: expenseSlices,
                    currency: currency,
                    onSelectCategory: onSelectCategory
                )
            }
            AskAIToolbar(
                filter: monthFilter,
                expenseCount: expenseCount,
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

    private func presentAskAIToast(provider: AIProvider) {
        askAIToastTask?.cancel()
        withAnimation(Motion.standard) {
            askAIToastProvider = provider
        }
        askAIToastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.standard) {
                askAIToastProvider = nil
            }
        }
    }
}
