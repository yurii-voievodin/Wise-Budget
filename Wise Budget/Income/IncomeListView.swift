import SwiftUI
import SwiftData

struct IncomeListView: View {
    @Environment(\.modelContext) private var modelContext


    @State private var isAddingIncome = false
    @State private var incomeToEdit: Income?
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())

    var body: some View {
        IncomeQueryListView(
            year: year,
            month: month,
            incomeToEdit: $incomeToEdit
        )
        .id(year * 100 + month)
        .navigationTitle("")
        .toolbar {
            MonthNavigationToolbar(year: $year, month: $month)
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
