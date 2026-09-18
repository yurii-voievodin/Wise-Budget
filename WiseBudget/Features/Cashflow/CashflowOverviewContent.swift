import SwiftUI

struct CashflowOverviewContent: View {
    let aggregate: CashflowAggregate
    let currency: String

    private let monthColumns = [
        GridItem(.adaptive(minimum: 320), spacing: Layout.Spacing.large)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.Spacing.large) {
                if aggregate.months.isEmpty {
                    Text("No income or expenses for this period")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Layout.Spacing.large)
                        .cardBackground()
                } else {
                    VStack(alignment: .leading, spacing: Layout.Spacing.medium) {
                        Text(aggregate.periodLabel)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        CashflowStatGrid(
                            income: aggregate.totalIncome,
                            expenses: aggregate.totalExpenses,
                            balance: aggregate.balance,
                            currency: currency
                        )
                    }
                    .padding(Layout.Spacing.medium)
                    .cardBackground()

                    LazyVGrid(columns: monthColumns, spacing: Layout.Spacing.large) {
                        ForEach(aggregate.months) { totals in
                            MonthCashflowCard(totals: totals, currency: currency)
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.medium)
            .padding(.vertical, Layout.Spacing.large)
        }
    }
}
