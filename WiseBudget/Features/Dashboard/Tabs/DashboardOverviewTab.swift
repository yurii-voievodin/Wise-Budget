import SwiftUI

struct DashboardOverviewTab: View {
    let summary: SpendingSummary
    let scopeKey: String
    let shouldShowBudgetPacing: Bool
    let daysRemainingInMonth: Int
    let dailyAllowance: Decimal
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let balance: Decimal
    let incomeDailyAverage: Decimal
    let expenseDailyAverage: Decimal
    let dailyBalance: Decimal
    let currency: String
    let recentTransactions: [DashboardRecentTransaction]
    let onSelectTransaction: (DashboardRecentTransaction) -> Void

    var body: some View {
        Form {
            MonthlyInsightsCard(summary: summary, scopeKey: scopeKey)
            if shouldShowBudgetPacing {
                DashboardBudgetPacingSection(
                    daysRemainingInMonth: daysRemainingInMonth,
                    dailyAllowance: dailyAllowance,
                    currency: currency
                )
            }
            DashboardMonthSummarySection(
                totalIncome: totalIncome,
                totalExpenses: totalExpenses,
                balance: balance,
                currency: currency
            )
            DashboardDailyAveragesSection(
                incomeDailyAverage: incomeDailyAverage,
                expenseDailyAverage: expenseDailyAverage,
                dailyBalance: dailyBalance,
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
