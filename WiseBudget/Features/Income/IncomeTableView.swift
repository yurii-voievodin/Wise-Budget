import SwiftUI
import SwiftData

/// Spreadsheet-style view of the same incomes shown in `IncomeQueryListView`.
/// Mirrors `ExpenseTableView` so the two feature pairs stay symmetrical.
struct IncomeTableView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @Query(sort: \IncomeCategory.name) private var categories: [IncomeCategory]
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let filter: MonthFilter
    let selectedCategoryName: String?
    let searchText: String
    @Binding var incomeToEdit: Income?

    @State private var sortOrder: [KeyPathComparator<Income>] = [
        KeyPathComparator(\Income.date, order: .reverse)
    ]
    @State private var selection: Set<PersistentIdentifier> = []
    @State private var pendingDeletion: [Income] = []

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
        let categoryName = selectedCategoryName
        self._incomes = Query(
            filter: #Predicate<Income> { income in
                income.date >= startDate && income.date < endDate &&
                (categoryName == nil || income.category?.name == categoryName)
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
        result = result.filterBySource(filter.sourceFilter)
        result = result.filterBySearchText(
            searchText,
            descriptionText: { $0.descriptionText },
            categoryName: { $0.category?.name },
            extraField: { $0.source }
        )
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
                HStack(spacing: Layout.Spacing.tight) {
                    if income.isInternalTransfer {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(.secondary)
                            .help("Internal transfer — excluded from statistics")
                    }
                    Text(income.descriptionText ?? (income.isInternalTransfer ? "Transfer" : "—"))
                        .foregroundStyle(income.descriptionText == nil ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    TransactionSourceBadge(externalId: income.externalId)
                }
                .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }

            TableColumn("Category") { income in
                Group {
                    if let name = income.category?.name {
                        HStack(spacing: Layout.Spacing.snug) {
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
                HStack(spacing: Layout.Spacing.tight) {
                    Spacer()
                    Text(income.amount, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                    Text(income.currency)
                        .foregroundStyle(income.currency == defaultCurrency ? .primary : .secondary)
                }
                .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }
            .width(min: 100, ideal: 130)

            TableColumn("In \(defaultCurrency)") { income in
                BaseCurrencyAmountCell(item: income, defaultCurrency: defaultCurrency)
                    .modifier(TransferRowStyle(isTransfer: income.isInternalTransfer))
            }
            .width(min: 90, ideal: 120)
        }
        .contextMenu(forSelectionType: PersistentIdentifier.self) { ids in
            let items = incomes.filter { ids.contains($0.persistentModelID) }
            if items.count == 1, let income = items.first {
                Button("Edit…") {
                    incomeToEdit = income
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
                Button(items.count == 1 ? "Delete…" : "Delete \(items.count) Incomes…", role: .destructive) {
                    pendingDeletion = items
                }
            }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first,
               let income = incomes.first(where: { $0.persistentModelID == id }) {
                incomeToEdit = income
                selection = []
            }
        }
        .bulkDeleteConfirmation(
            items: $pendingDeletion,
            singularNoun: "income",
            pluralNoun: "incomes",
            onConfirm: delete
        )
    }

    private func delete(_ items: [Income]) {
        for income in items {
            modelContext.delete(income)
        }
        selection = []
        pendingDeletion = []
    }

    private func setTransfer(_ value: Bool, for items: [Income]) {
        for income in items where income.isInternalTransfer != value {
            income.isInternalTransfer = value
        }
    }

    private func setCategory(_ category: IncomeCategory?, for items: [Income]) {
        for income in items where income.category != category {
            income.category = category
        }
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
