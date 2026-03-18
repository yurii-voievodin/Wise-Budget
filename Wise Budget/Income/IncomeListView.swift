import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var selectedTab: IncomeTab = .income
    @Binding var filter: MonthFilter

    enum IncomeTab: Hashable {
        case income
        case chart
        case statistics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Income", systemImage: "list.bullet", value: .income) {
                IncomeQueryListView(
                    filter: filter,
                    incomeToEdit: $incomeToEdit
                )
                .id(filter)
            }
            Tab("Chart", systemImage: "chart.pie", value: .chart) {
                IncomeCategoryChartView(filter: filter)
                    .id(filter)
            }
            Tab("Statistics", systemImage: "tablecells", value: .statistics) {
                IncomeStatisticsView(filter: filter)
                    .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            if selectedTab == .income {
                ToolbarItem {
                    Button(action: { isAddingIncome = true }) {
                        Label("Add Income", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingIncome) {
            AddIncomeSheet { amount, currency, date, category, descriptionText in
                withAnimation {
                    let newIncome = Income(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText)
                    modelContext.insert(newIncome)
                }
            }
        }
        .sheet(item: $incomeToEdit) { income in
            AddIncomeSheet(income: income) { amount, currency, date, category, descriptionText in
                withAnimation {
                    income.amount = amount
                    income.currency = currency
                    income.date = date
                    income.category = category
                    income.descriptionText = descriptionText
                }
            }
        }
    }
}
