import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var selectedTab: IncomeTab = .income
    @State private var isManagingCategories = false
    @State private var syncService = BankSyncService()
    @Binding var filter: MonthFilter
    @Binding var selectedSidebarItem: SidebarItem

    enum IncomeTab: Hashable {
        case income
        case statistics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Income", systemImage: "list.bullet", value: .income) {
                IncomeQueryListView(
                    filter: filter,
                    incomeToEdit: $incomeToEdit,
                    isAddingIncome: $isAddingIncome,
                    selectedSidebarItem: $selectedSidebarItem,
                    syncService: syncService
                )
                .id(filter)
            }
            Tab("Statistics", systemImage: "chart.pie", value: .statistics) {
                IncomeStatisticsView(filter: filter, syncService: syncService)
                    .id(filter)
            }
        }
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            BankSyncToolbar(syncService: syncService, filter: filter)
            ToolbarItem {
                Button(action: { isManagingCategories = true }) {
                    Label("Manage Categories", systemImage: "tag")
                }
            }
            if selectedTab == .income {
                ToolbarItem {
                    Button(action: { isAddingIncome = true }) {
                        Label("Add Income", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingIncome) {
            IncomeFormSheet { amount, currency, date, category, descriptionText, source, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    let newIncome = Income(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText, source: source, baseCurrencyAmount: baseCurrencyAmount, baseCurrency: baseCurrency)
                    modelContext.insert(newIncome)
                }
            }
        }
        .sheet(item: $incomeToEdit) { income in
            IncomeFormSheet(income: income) { amount, currency, date, category, descriptionText, source, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    income.amount = amount
                    income.currency = currency
                    income.date = date
                    income.category = category
                    income.descriptionText = descriptionText
                    income.source = source
                    income.baseCurrencyAmount = baseCurrencyAmount
                    income.baseCurrency = baseCurrency
                }
            }
        }
        .sheet(isPresented: $isManagingCategories) {
            IncomeCategoryManagementSheet()
        }
    }
}
