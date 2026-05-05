import SwiftUI

struct DashboardOverviewTab: View {
    let summary: SpendingSummary
    let metrics: DashboardMetrics
    let scopeKey: String
    let currency: String
    let recentTransactions: [DashboardRecentTransaction]
    let onSelectTransaction: (DashboardRecentTransaction) -> Void

    var body: some View {
        Form {
            MonthlyInsightsCard(summary: summary, scopeKey: scopeKey)
            if metrics.shouldShowBudgetPacing {
                DashboardBudgetPacingSection(
                    daysRemainingInMonth: metrics.daysRemainingInMonth,
                    dailyAllowance: metrics.dailyAllowance,
                    currency: currency
                )
            }
            DashboardKPIGridSection(
                totalIncome: metrics.totalIncome,
                totalExpenses: metrics.totalExpenses,
                balance: metrics.balance,
                incomeDailyAverage: metrics.incomeDailyAverage,
                expenseDailyAverage: metrics.expenseDailyAverage,
                dailyBalance: metrics.dailyBalance,
                currency: currency
            )
            DashboardRecentTransactionsSection(
                transactions: recentTransactions,
                onTap: onSelectTransaction
            )
        }
        .formStyle(.grouped)
    }
}
