import SwiftUI
import SwiftData

/// Spreadsheet-style view of the same expenses shown in `ExpenseQueryListView`.
/// Sorting works through SwiftUI's `Table` `KeyPathComparator` — taps on the
/// header row reorder the rows. Selecting a row opens the edit sheet so the
/// table stays a peer of the list rather than a read-only export.
struct ExpenseTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    let selectedCategoryName: String?
    let searchText: String
    @Binding var expenseToEdit: Expense?

    @State private var sortOrder: [KeyPathComparator<Expense>] = [
        KeyPathComparator(\Expense.date, order: .reverse)
    ]
    @State private var selection: PersistentIdentifier?

    init(
        filter: MonthFilter,
        selectedCategoryName: String?,
        searchText: String,
        expenseToEdit: Binding<Expense?>
    ) {
        self.filter = filter
        self.selectedCategoryName = selectedCategoryName
        self.searchText = searchText
        self._expenseToEdit = expenseToEdit

        let startDate = filter.startOfMonth
        let endDate = filter.startOfNextMonth
        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate
            },
            sort: \.date,
            order: .reverse
        )
    }

    private var rows: [Expense] {
        var result = expenses
        if filter.foreignOnly {
            result = result.filterForeignCurrency(defaultCurrency: defaultCurrency)
        }
        if let categoryName = selectedCategoryName {
            result = result.filter { $0.category?.name == categoryName }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let needle = trimmed.lowercased()
            result = result.filter { expense in
                if expense.descriptionText?.lowercased().contains(needle) == true { return true }
                if expense.destination?.lowercased().contains(needle) == true { return true }
                if expense.category?.name.lowercased().contains(needle) == true { return true }
                if "\(expense.amount)".contains(needle) { return true }
                if let base = expense.baseCurrencyAmount, "\(base)".contains(needle) { return true }
                return false
            }
        }
        return result.sorted(using: sortOrder)
    }

    var body: some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.date) { expense in
                Text(expense.date, format: .dateTime.day().month(.abbreviated))
                    .monospacedDigit()
                    .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }
            .width(min: 70, ideal: 90)

            TableColumn("Description") { expense in
                HStack(spacing: 4) {
                    if expense.isInternalTransfer {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Internal transfer — excluded from statistics")
                    }
                    Text(expense.descriptionText ?? (expense.isInternalTransfer ? "Transfer" : "—"))
                        .foregroundStyle(expense.descriptionText == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }

            TableColumn("Category") { expense in
                Group {
                    if let name = expense.category?.name {
                        HStack(spacing: 6) {
                            Image(systemName: expense.category?.displayIconName ?? "folder")
                                .foregroundStyle(DefaultExpenseCategory.color(for: name))
                            Text(name)
                                .lineLimit(1)
                        }
                    } else {
                        Text("—").foregroundStyle(.secondary)
                    }
                }
                .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }
            .width(min: 100, ideal: 140)

            TableColumn("Destination") { expense in
                Text(expense.destination ?? "—")
                    .foregroundStyle(expense.destination == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }

            TableColumn("Amount", value: \.amount) { expense in
                HStack(spacing: 4) {
                    Spacer()
                    Text(expense.amount, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text(expense.currency)
                        .foregroundStyle(expense.currency == defaultCurrency ? .primary : .secondary)
                }
                .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }
            .width(min: 100, ideal: 130)
        }
        .onChange(of: selection) { _, newValue in
            if let id = newValue, let expense = expenses.first(where: { $0.persistentModelID == id }) {
                expenseToEdit = expense
                selection = nil
            }
        }
    }
}

/// Dim transfer rows so they recede the way they do in `TransactionRowView`.
private struct TransferRowStyle: ViewModifier {
    let isTransfer: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isTransfer ? 0.55 : 1)
            .foregroundStyle(isTransfer ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
    }
}

#Preview {
    @Previewable @State var expenseToEdit: Expense? = nil
    ExpenseTableView(
        filter: MonthFilter(year: 2026, month: 3),
        selectedCategoryName: nil,
        searchText: "",
        expenseToEdit: $expenseToEdit
    )
    .modelContainer(PreviewSampleData.container)
    .frame(width: 800, height: 500)
}
