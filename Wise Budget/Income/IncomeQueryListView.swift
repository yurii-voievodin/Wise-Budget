import SwiftUI
import SwiftData

struct IncomeQueryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @Query private var allIncomes: [Income]

    @AppStorage("defaultCurrency") private var defaultCurrency: String = Locale.current.currency?.identifier ?? "USD"

    let filter: MonthFilter
    @Binding var incomeToEdit: Income?
    @Binding var isAddingIncome: Bool
    @Binding var selectedSidebarItem: SidebarItem

    init(filter: MonthFilter, incomeToEdit: Binding<Income?>, isAddingIncome: Binding<Bool>, selectedSidebarItem: Binding<SidebarItem>) {
        self.filter = filter
        self._incomeToEdit = incomeToEdit
        self._isAddingIncome = isAddingIncome
        self._selectedSidebarItem = selectedSidebarItem

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth

        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var filteredIncomes: [Income] {
        guard filter.foreignOnly else { return incomes }
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
        if allIncomes.isEmpty {
            emptyStateView
        } else {
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
                                        if let category = income.category {
                                            Label(category.name, systemImage: category.displayIconName)
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
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Income Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add your first income, import from a CSV file,\nor connect a bank account to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    isAddingIncome = true
                } label: {
                    Label("Add Income", systemImage: "plus")
                }

                Button {
                    selectedSidebarItem = .bankConnections
                } label: {
                    Label("Connect Bank", systemImage: "link")
                }
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
