import SwiftUI
import SwiftData

/// Spreadsheet-style view of the same expenses shown in `ExpenseQueryListView`.
/// Sorting works through SwiftUI's `Table` `KeyPathComparator` — taps on the
/// header row reorder the rows. Selecting a row opens the edit sheet so the
/// table stays a peer of the list rather than a read-only export.
struct ExpenseTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    let selectedCategoryName: String?
    let searchText: String
    @Binding var expenseToEdit: Expense?

    @State private var sortOrder: [KeyPathComparator<Expense>] = [
        KeyPathComparator(\Expense.date, order: .reverse)
    ]
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var pendingDeletion: [Expense] = []

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
        let categoryName = selectedCategoryName
        self._expenses = Query(
            filter: #Predicate<Expense> { expense in
                expense.date >= startDate && expense.date < endDate &&
                (categoryName == nil || expense.category?.name == categoryName)
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
        result = result.filterBySource(filter.sourceFilter)
        result = result.filterBySearchText(
            searchText,
            descriptionText: { $0.descriptionText },
            categoryName: { $0.category?.name },
            extraField: { $0.destination }
        )
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
                HStack(spacing: Layout.Spacing.tight) {
                    if expense.isInternalTransfer {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Internal transfer — excluded from statistics")
                    }
                    Text(expense.descriptionText ?? (expense.isInternalTransfer ? "Transfer" : "—"))
                        .foregroundStyle(expense.descriptionText == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    TransactionSourceBadge(externalId: expense.externalId)
                }
                .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }

            TableColumn("Category") { expense in
                Group {
                    if let name = expense.category?.name {
                        HStack(spacing: Layout.Spacing.snug) {
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
                HStack(spacing: Layout.Spacing.tight) {
                    Spacer()
                    Text(expense.amount, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text(expense.currency)
                        .foregroundStyle(expense.currency == defaultCurrency ? .primary : .secondary)
                }
                .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }
            .width(min: 100, ideal: 130)

            TableColumn("In \(defaultCurrency)") { expense in
                BaseCurrencyAmountCell(item: expense, defaultCurrency: defaultCurrency)
                    .modifier(TransferRowStyle(isTransfer: expense.isInternalTransfer))
            }
            .width(min: 90, ideal: 120)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            let items = expenses.filter { ids.contains($0.persistentModelID) }
            if items.count == 1, let expense = items.first {
                Button("Edit…") {
                    expenseToEdit = expense
                    selection = []
                }
                Divider()
            }
            if !items.isEmpty {
                let allTransfer = items.allSatisfy(\.isInternalTransfer)
                let noneTransfer = items.allSatisfy { !$0.isInternalTransfer }
                if !allTransfer {
                    Button(items.count == 1 ? "Mark as Transfer" : "Mark \(items.count) as Transfers") {
                        setTransfer(true, for: items)
                    }
                }
                if !noneTransfer {
                    Button(items.count == 1 ? "Unmark Transfer" : "Unmark \(items.count) Transfers") {
                        setTransfer(false, for: items)
                    }
                }
                Divider()
                BulkCategoryMenu(categories: categories) { setCategory($0, for: items) }
                Divider()
                Button(items.count == 1 ? "Delete…" : "Delete \(items.count) Expenses…", role: .destructive) {
                    pendingDeletion = items
                }
            }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first,
               let expense = expenses.first(where: { $0.persistentModelID == id }) {
                expenseToEdit = expense
                selection = []
            }
        }
        .bulkDeleteConfirmation(
            items: $pendingDeletion,
            singularNoun: "expense",
            pluralNoun: "expenses",
            onConfirm: delete
        )
    }

    private func delete(_ items: [Expense]) {
        for expense in items {
            modelContext.delete(expense)
        }
        selection = []
        pendingDeletion = []
    }

    private func setTransfer(_ value: Bool, for items: [Expense]) {
        for expense in items where expense.isInternalTransfer != value {
            expense.isInternalTransfer = value
        }
    }

    private func setCategory(_ category: ExpenseCategory?, for items: [Expense]) {
        for expense in items where expense.category != category {
            expense.category = category
        }
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
