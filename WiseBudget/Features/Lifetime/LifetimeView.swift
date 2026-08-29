import SwiftUI
import SwiftData

struct LifetimeView: View {
    @Query(filter: #Predicate<Expense> { !$0.isInternalTransfer }, sort: \Expense.date) private var expenses: [Expense]
    @Query(filter: #Predicate<Income> { !$0.isInternalTransfer }, sort: \Income.date) private var incomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    private var aggregate: LifetimeAggregate {
        LifetimeAggregate.make(expenses: expenses, incomes: incomes, currency: defaultCurrency)
    }

    var body: some View {
        Form {
            let data = aggregate
            if !data.hasData {
                Section {
                    Text("No data yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                LifetimeKPISection(
                    totalIncome: data.totalIncome,
                    totalExpenses: data.totalExpenses,
                    net: data.net,
                    span: LifetimeAggregate.formatSpan(from: data.firstDate, to: data.lastDate),
                    currency: defaultCurrency
                )

                YearlyDualBarSection(rows: data.yearRows)

                CumulativeNetSection(points: data.cumulativeNet)

                CategoryChartSection(
                    title: "Top Expense Categories",
                    slices: data.expenseCategories,
                    currency: defaultCurrency,
                    emptyText: "No expenses yet",
                    colorMap: DefaultExpenseCategory.chartColorMap,
                    sortOrderStorageKey: "lifetimeExpenseCategorySortOrder",
                    hidesChart: true
                )

                CategoryChartSection(
                    title: "Top Income Categories",
                    slices: data.incomeCategories,
                    currency: defaultCurrency,
                    emptyText: "No income yet",
                    colorMap: DefaultIncomeCategory.chartColorMap,
                    sortOrderStorageKey: "lifetimeIncomeCategorySortOrder",
                    hidesChart: true
                )

                LifetimeYearTableSection(rows: data.yearRows, currency: defaultCurrency)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("")
    }
}

#Preview {
    LifetimeView()
        .modelContainer(PreviewSampleData.container)
        .frame(width: 700, height: 800)
}
