import SwiftUI
import SwiftData

struct TransactionListContent<T: CurrencyConvertible & PersistentModel>: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(DefaultCurrency.userDefaultsKey) private var defaultCurrency: String = DefaultCurrency.localeFallback

    let groups: [TransactionGroup<T>]
    let hasAnyItems: Bool
    let hasBankToken: Bool
    let filter: MonthFilter
    let syncService: BankSyncService
    let emptyTitle: String
    let emptyIcon: String
    let monthEmptyTitle: String
    let monthEmptyIcon: String
    let addLabel: String
    let descriptionText: (T) -> String?
    let categoryName: (T) -> String?
    let categoryIcon: (T) -> String?
    var categoryColor: (T) -> Color? = { _ in nil }
    let extraField: (T) -> String?
    var amountTintColor: Color?
    var onSelect: (T) -> Void
    var onAdd: () -> Void
    var onNavigateToBank: () -> Void

    var body: some View {
        Group {
            if !hasAnyItems && !hasBankToken {
                TransactionEmptyStateView(
                    title: emptyTitle,
                    systemImage: emptyIcon,
                    addLabel: addLabel,
                    onAdd: onAdd,
                    onNavigateToBank: onNavigateToBank
                )
            } else if groups.isEmpty {
                MonthEmptyStateView(
                    title: monthEmptyTitle,
                    systemImage: monthEmptyIcon,
                    filter: filter,
                    syncService: syncService
                )
            } else {
                List {
                    ForEach(groups) { group in
                        Section {
                            ForEach(group.items) { item in
                                Button {
                                    onSelect(item)
                                } label: {
                                    TransactionRowView(
                                        descriptionText: descriptionText(item),
                                        categoryName: categoryName(item),
                                        categoryIcon: categoryIcon(item),
                                        categoryColor: categoryColor(item),
                                        extraField: extraField(item),
                                        item: item,
                                        amountTintColor: amountTintColor
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                withAnimation {
                                    for index in offsets {
                                        modelContext.delete(group.items[index])
                                    }
                                }
                            }
                        } header: {
                            HStack(spacing: 4) {
                                Text(group.date, format: Date.FormatStyle(date: .long))
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(dayTotal(for: group.items), format: .number.precision(.fractionLength(0)))
                                    .fontWeight(.medium)
                                    .monospacedDigit()
                                Text(defaultCurrency)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private func dayTotal(for items: [T]) -> Decimal {
        items
            .filter { !$0.isInternalTransfer }
            .reduce(Decimal.zero) { $0 + ($1.convertedAmount(to: defaultCurrency) ?? .zero) }
    }
}
