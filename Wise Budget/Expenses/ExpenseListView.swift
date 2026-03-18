import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var expenseFilter: ExpenseFilter

    @State private var isAddingExpense = false
    @State private var expenseToEdit: Expense?
    @State private var isDatePickerPresented = false
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())

    private var monthTitle: String {
        expenseFilter.startOfMonth.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        ExpenseQueryListView(
            filter: expenseFilter,
            expenseToEdit: $expenseToEdit
        )
        .id(expenseFilter)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    Button {
                        moveMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button {
                        pickerYear = expenseFilter.year
                        pickerMonth = expenseFilter.month
                        isDatePickerPresented.toggle()
                    } label: {
                        Text(monthTitle)
                            .font(.headline)
                    }
                    .popover(isPresented: $isDatePickerPresented) {
                        VStack(spacing: 12) {
                            HStack {
                                Picker("Month", selection: $pickerMonth) {
                                    ForEach(1...12, id: \.self) { month in
                                        Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                                    }
                                }
                                .labelsHidden()

                                Picker("Year", selection: $pickerYear) {
                                    ForEach((2020...2030), id: \.self) { year in
                                        Text(String(year)).tag(year)
                                    }
                                }
                                .labelsHidden()
                            }

                            HStack {
                                Button("Current Month") {
                                    let now = ExpenseFilter.currentMonth()
                                    expenseFilter = ExpenseFilter(
                                        year: now.year,
                                        month: now.month,
                                        foreignOnly: expenseFilter.foreignOnly
                                    )
                                    isDatePickerPresented = false
                                }

                                Button("Go") {
                                    expenseFilter = ExpenseFilter(
                                        year: pickerYear,
                                        month: pickerMonth,
                                        foreignOnly: expenseFilter.foreignOnly
                                    )
                                    isDatePickerPresented = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding()
                    }
                    Button {
                        moveMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            ToolbarItem {
                Menu {
                    Button {
                        expenseFilter.foreignOnly = false
                    } label: {
                        if !expenseFilter.foreignOnly {
                            Label("None", systemImage: "checkmark")
                        } else {
                            Text("None")
                        }
                    }
                    Button {
                        expenseFilter.foreignOnly = true
                    } label: {
                        if expenseFilter.foreignOnly {
                            Label("Foreign currency", systemImage: "checkmark")
                        } else {
                            Text("Foreign currency")
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle\(expenseFilter.foreignOnly ? ".fill" : "")")
                }
            }
            ToolbarItem {
                Button(action: { isAddingExpense = true }) {
                    Label("Add Expense", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingExpense) {
            AddExpenseSheet { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    let newExpense = Expense(amount: amount, currency: currency, date: date, category: category, descriptionText: descriptionText, destination: destination, baseCurrencyAmount: baseCurrencyAmount, baseCurrency: baseCurrency)
                    modelContext.insert(newExpense)
                }
            }
        }
        .sheet(item: $expenseToEdit) { expense in
            AddExpenseSheet(expense: expense) { amount, currency, date, category, descriptionText, destination, baseCurrencyAmount, baseCurrency in
                withAnimation {
                    expense.amount = amount
                    expense.currency = currency
                    expense.date = date
                    expense.category = category
                    expense.descriptionText = descriptionText
                    expense.destination = destination
                    expense.baseCurrencyAmount = baseCurrencyAmount
                    expense.baseCurrency = baseCurrency
                }
            }
        }
    }

    private func moveMonth(by delta: Int) {
        expenseFilter = expenseFilter.moved(by: delta)
    }
}



