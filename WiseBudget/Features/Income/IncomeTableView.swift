import SwiftUI
import SwiftData

/// Spreadsheet-style view of the same incomes shown in `IncomeQueryListView`.
/// Mirrors `ExpenseTableView` so the two feature pairs stay symmetrical.
struct IncomeTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    let selectedCategoryName: String?
    let searchText: String
    @Binding var incomeToEdit: Income?

    @State private var sortOrder: [KeyPathComparator<Income>] = [
        KeyPathComparator(\Income.date, order: .reverse)
    ]
    @State private var selection: PersistentIdentifier?

    init(
        filter: MonthFilter,
        selectedCategoryName: String?,
        searchText: String,
        incomeToEdit: Binding<Income?>
    ) {
        self.filter = filter
        self.selectedCategoryName = selectedCategoryName
        self.searchText = searchText
        self._incomeToEdit = incomeToEdit

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

    private var rows: [Income] {
        var result = incomes
        if filter.foreignOnly {
            result = result.filterForeignCurrency(defaultCurrency: defaultCurrency)
        }
        if let categoryName = selectedCategoryName {
            result = result.filter { $0.category?.name == categoryName }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let needle = trimmed.lowercased()
            result = result.filter { income in
                if income.descriptionText?.lowercased().contains(needle) == true { return true }
                if income.source?.lowercased().contains(needle) == true { return true }
                if income.category?.name.lowercased().contains(needle) == true { return true }
                if "\(income.amount)".contains(needle) { return true }
                if let base = income.baseCurrencyAmount, "\(base)".contains(needle) { return true }
                return false
            }
        }
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { income in
                Text(income.date, format: .dateTime.day().month(.abbreviated))
                    .monospacedDigit()
                    .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }
            .width(min: 70, ideal: 90)

            TableColumn("Description") { income in
                HStack(spacing: 4) {
                    if income.isInternalTransfer {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Internal transfer — excluded from statistics")
                    }
                    Text(income.descriptionText ?? (income.isInternalTransfer ? "Transfer" : "—"))
                        .foregroundStyle(income.descriptionText == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }

            TableColumn("Category") { income in
                Group {
                    if let name = income.category?.name {
                        HStack(spacing: 6) {
                            Image(systemName: income.category?.displayIconName ?? "folder")
                                .foregroundStyle(DefaultIncomeCategory.color(for: name))
                            Text(name)
                                .lineLimit(1)
                        }
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
                .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }
            .width(min: 100, ideal: 140)

            TableColumn("Source") { income in
                Text(income.source ?? "—")
                    .foregroundStyle(income.source == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }

            TableColumn("Amount", value: \.amount) { income in
                HStack(spacing: 4) {
                    Spacer()
                    Text(income.amount, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text(income.currency)
                        .foregroundStyle(income.currency == defaultCurrency ? .primary : .secondary)
                }
                .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }
            .width(min: 100, ideal: 130)
        }
        .onChange(of: selection) { _, newValue in
            if let id = newValue, let income = incomes.first(where: { $0.persistentModelID == id }) {
                incomeToEdit = income
                selection = nil
            }
        }
    }
}

private struct TransferRowStyle: ViewModifier {
    let isTransfer: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isTransfer ? 0.55 : 1)
            .foregroundStyle(isTransfer ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }
}

#Preview {
    @Previewable @State var incomeToEdit: Income? = nil
    IncomeTableView(
        filter: MonthFilter(year: 2026, month: 3),
        selectedCategoryName: nil,
        searchText: "",
        incomeToEdit: $incomeToEdit
    )
    .modelContainer(PreviewSampleData.container)
    .frame(width: 800, height: 500)
}
