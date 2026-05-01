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

    // MARK: - Month Range

    private var monthRange: [MonthKey] {
        let calendar = Calendar.current
        switch timeRange {
        case .sixMonths:
            let current = MonthKey(year: filter.year, month: filter.month)
            return (0..<6).reversed().compactMap { offset in
                let comps = DateComponents(year: current.year, month: current.month - offset)
                guard let date = calendar.date(from: comps),
                      let year = calendar.dateComponents([.year, .month], from: date).year,
                      let month = calendar.dateComponents([.year, .month], from: date).month else { return nil }
                return MonthKey(year: year, month: month)
            }
        case .year:
            return (1...12).map { MonthKey(year: filter.year, month: $0) }
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

        // Reverse so the most recent month is first.
        return monthRange.reversed().map { key in
            MonthlyTotals(month: key, income: income[key] ?? 0, expenses: expenses[key] ?? 0)
        }
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Time Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
            }

            let activeMonths = monthlyTotals.filter(\.hasActivity)

            if activeMonths.isEmpty {
                Section {
                    Text("No income or expenses for this period")
                        .foregroundStyle(.secondary)
                }
            } else {
                let periodIncome = activeMonths.reduce(Decimal.zero) { $0 + $1.income }
                let periodExpenses = activeMonths.reduce(Decimal.zero) { $0 + $1.expenses }
                let periodBalance = periodIncome - periodExpenses

                Section(periodLabel) {
                    LabeledContent("Income") {
                        Text("\(periodIncome, format: .number.precision(.fractionLength(0))) \(defaultCurrency)")
                            .monospacedDigit()
                            .foregroundStyle(.income)
                    }
                    LabeledContent("Expenses") {
                        Text("\(periodExpenses, format: .number.precision(.fractionLength(0))) \(defaultCurrency)")
                            .monospacedDigit()
                            .foregroundStyle(.expense)
                    }
                    LabeledContent("Balance") {
                        Text("\(periodBalance >= .zero ? "+" : "")\(periodBalance, format: .number.precision(.fractionLength(0))) \(defaultCurrency)")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .foregroundStyle(periodBalance >= .zero ? .income : .expense)
                    }
                }

                ForEach(activeMonths, id: \.month) { totals in
                    Section(totals.month.fullLabel) {
                        CashflowBarRow(
                            label: "Income",
                            amount: totals.income,
                            maxValue: max(totals.income, totals.expenses),
                            tint: .income,
                            currency: defaultCurrency
                        )
                        CashflowBarRow(
                            label: "Expenses",
                            amount: totals.expenses,
                            maxValue: max(totals.income, totals.expenses),
                            tint: .expense,
                            currency: defaultCurrency
                        )
                        LabeledContent("Balance") {
                            Text("\(totals.balance >= .zero ? "+" : "")\(totals.balance, format: .number.precision(.fractionLength(0))) \(defaultCurrency)")
                                .monospacedDigit()
                                .fontWeight(.semibold)
                                .foregroundStyle(totals.balance >= .zero ? .income : .expense)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct CashflowBarRow: View {
    let label: String
    let amount: Decimal
    let maxValue: Decimal
    let tint: Color
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amount, format: .number.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                + Text(" \(currency)")
                    .foregroundStyle(.secondary)
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
            .frame(height: 8)
        }
        .padding(.vertical, 2)
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
