import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext


    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var filter: MonthFilter = .currentMonth()

    var body: some View {
        IncomeQueryListView(
            filter: filter,
            incomeToEdit: $incomeToEdit
        )
        .id(filter)
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $filter.year, month: $filter.month)
            ForeignCurrencyFilterToolbar(foreignOnly: $filter.foreignOnly)
            ToolbarItem {
                Button(action: { isAddingIncome = true }) {
                    Label("Add Income", systemImage: "plus")
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
