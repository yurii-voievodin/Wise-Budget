import SwiftUI
import SwiftData

struct IncomeQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let foreignOnly: Bool
    @Binding var incomeToEdit: Income?

    init(year: Int, month: Int, foreignOnly: Bool, incomeToEdit: Binding<Income?>) {
        self.foreignOnly = foreignOnly
        self._incomeToEdit = incomeToEdit

        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? Date()

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var filteredIncomes: [Income] {
        guard foreignOnly else { return incomes }
        return incomes.filterForeignCurrency(defaultCurrency: defaultCurrency)
    }

    private var groupedIncomes: [(date: Date, incomes: [Income])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredIncomes) { income in
            calendar.startOfDay(for: income.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, incomes: $0.value) }
    }

    var body: some View {
        List {
            ForEach(groupedIncomes, id: \.date) { group in
                Section {
                    ForEach(group.incomes) { income in
                        Button {
                            incomeToEdit = income
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let desc = income.descriptionText {
                                        Text(desc)
                                            .font(.body)
                                            .fontWeight(.medium)
                                    }
                                    if let categoryName = income.category?.name {
                                        Text(categoryName)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                CurrencyAmountView(item: income)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        deleteIncomes(from: group.incomes, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(group.date, format: Date.FormatStyle(date: .long))
                        Spacer()
                        Text(dayTotal(for: group.incomes), format: .number)
                    }
                }
            }
        }
    }

    private func dayTotal(for incomes: [Income]) -> Decimal {
        incomes.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private func deleteIncomes(from groupIncomes: [Income], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groupIncomes[index])
            }
        }
    }
}
