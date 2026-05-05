import SwiftUI
import SwiftData

struct CashflowView: View {
    @Query(filter: #Predicate<Expense> { !$0.isInternalTransfer }, sort: \Expense.date) private var allExpenses: [Expense]
    @Query(filter: #Predicate<Income> { !$0.isInternalTransfer }, sort: \Income.date) private var allIncomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter

    enum TimeRange: String, CaseIterable, Identifiable {
        case sixMonths = "6 Months"
        case year = "Year"

        var id: Self { self }
    }

    @State private var timeRange: TimeRange = .sixMonths

    private let statColumns = [
        GridItem(.adaptive(minimum: 200), spacing: 12)
    ]

    private let monthColumns = [
        GridItem(.adaptive(minimum: 320), spacing: 16)
    ]

    // MARK: - Month Range

    private var monthRange: [MonthKey] {
        switch timeRange {
        case .sixMonths:
            return MonthKey.recent(6, endingAt: MonthKey(year: filter.year, month: filter.month))
        case .year:
            return MonthKey.allMonths(of: filter.year)
        }
    }

    // MARK: - Aggregation

    private struct MonthlyTotals {
        let month: MonthKey
        let income: Decimal
        let expenses: Decimal

        var balance: Decimal { income - expenses }
        var hasActivity: Bool { income > 0 || expenses > 0 }
    }

    private var periodLabel: String {
        guard let first = monthRange.first, let last = monthRange.last else { return "" }
        if first == last { return first.fullLabel }
        return "\(first.fullLabel) — \(last.fullLabel)"
    }

    private var monthlyTotals: [MonthlyTotals] {
        let calendar = Calendar.current
        let validMonths = Set(monthRange)

        var income: [MonthKey: Decimal] = [:]
        var expenses: [MonthKey: Decimal] = [:]

        for item in allIncomes {
            let c = calendar.dateComponents([.year, .month], from: item.date)
            guard let year = c.year, let month = c.month else { continue }
            let key = MonthKey(year: year, month: month)
            guard validMonths.contains(key) else { continue }
            income[key, default: 0] += item.convertedAmount(to: defaultCurrency) ?? .zero
        }
        for item in allExpenses {
            let c = calendar.dateComponents([.year, .month], from: item.date)
            guard let year = c.year, let month = c.month else { continue }
            let key = MonthKey(year: year, month: month)
            guard validMonths.contains(key) else { continue }
            expenses[key, default: 0] += item.convertedAmount(to: defaultCurrency) ?? .zero
        }

        return monthRange.reversed().map { key in
            MonthlyTotals(month: key, income: income[key] ?? 0, expenses: expenses[key] ?? 0)
        }
    }

    // MARK: - Body

    var body: some View {
        let activeMonths = monthlyTotals.filter(\.hasActivity)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if activeMonths.isEmpty {
                    Text("No income or expenses for this period")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .cardBackground()
                } else {
                    let periodIncome = activeMonths.reduce(Decimal.zero) { $0 + $1.income }
                    let periodExpenses = activeMonths.reduce(Decimal.zero) { $0 + $1.expenses }
                    let periodBalance = periodIncome - periodExpenses

                    VStack(alignment: .leading, spacing: 12) {
                        Text(periodLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        cashflowStatGrid(
                            income: periodIncome,
                            expenses: periodExpenses,
                            balance: periodBalance
                        )
                    }
                    .padding(12)
                    .cardBackground()

                    LazyVGrid(columns: monthColumns, spacing: 16) {
                        ForEach(activeMonths, id: \.month) { totals in
                            MonthCashflowCard(
                                month: totals.month,
                                income: totals.income,
                                expenses: totals.expenses,
                                balance: totals.balance,
                                currency: defaultCurrency
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "calendar")
                }
                .menuIndicator(.hidden)
                .help("Time Range")
                .accessibilityLabel("Time Range")
            }
        }
    }

    @ViewBuilder
    private func cashflowStatGrid(income: Decimal, expenses: Decimal, balance: Decimal) -> some View {
        LazyVGrid(columns: statColumns, spacing: 12) {
            StatCard(
                label: "Income",
                icon: "arrow.down.circle.fill",
                color: .income,
                amount: income,
                currency: defaultCurrency,
                bold: true,
                precision: 0
            )
            StatCard(
                label: "Expenses",
                icon: "arrow.up.circle.fill",
                color: .expense,
                amount: expenses,
                currency: defaultCurrency,
                bold: true,
                precision: 0
            )
            StatCard(
                label: "Balance",
                icon: balance >= .zero ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                color: balance >= .zero ? .income : .expense,
                amount: balance,
                currency: defaultCurrency,
                signed: true,
                bold: true,
                precision: 0
            )
        }
    }
}

private struct MonthCashflowCard: View {
    let month: MonthKey
    let income: Decimal
    let expenses: Decimal
    let balance: Decimal
    let currency: String

    private var scale: Decimal { max(income, expenses) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(month.fullLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            CashflowBarRow(
                label: "Income",
                amount: income,
                maxValue: scale,
                tint: .income,
                currency: currency
            )
            CashflowBarRow(
                label: "Expenses",
                amount: expenses,
                maxValue: scale,
                tint: .expense,
                currency: currency
            )

            Divider()

            HStack {
                Text("Balance")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amount: balance, currency: currency, signed: true, precision: 0)
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(balance >= .zero ? .income : .expense)
            }
        }
        .padding(12)
        .cardBackground()
    }
}

private struct CashflowBarRow: View {
    let label: String
    let amount: Decimal
    let maxValue: Decimal
    let tint: Color
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Text(amount, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                    Text(currency)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * widthRatio)
                }
            }
            .frame(height: 6)
        }
    }

    private var widthRatio: Double {
        guard maxValue > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: amount / maxValue).doubleValue
        return min(max(ratio, 0), 1)
    }
}

#Preview {
    CashflowView(filter: MonthFilter(year: 2026, month: 3))
        .modelContainer(PreviewSampleData.container)
        .frame(width: 600, height: 700)
}
