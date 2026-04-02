import SwiftUI
import SwiftData

struct TransactionGroup<T: CurrencyConvertible>: Identifiable {
    let date: Date
    let items: [T]
    var id: Date { date }
}

struct TransactionListContent<T: CurrencyConvertible & PersistentModel>: View {
    @Environment(\.modelContext) private var modelContext

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
    let extraField: (T) -> String?
    var onSelect: (T) -> Void
    var onAdd: () -> Void
    var onNavigateToBank: () -> Void

    var body: some View {
        Group {
            if !hasAnyItems && !hasBankToken {
                emptyStateView
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
                                        extraField: extraField(item),
                                        item: item
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
                            HStack {
                                Text(group.date, format: Date.FormatStyle(date: .long))
                                Spacer()
                                Text(dayTotal(for: group.items), format: .number)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: emptyIcon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(emptyTitle)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Add your first entry, import from a CSV file,\nor connect a bank account to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button {
                    onAdd()
                } label: {
                    Label(addLabel, systemImage: "plus")
                }
                Button {
                    onNavigateToBank()
                } label: {
                    Label("Connect Bank", systemImage: "link")
                }
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayTotal(for items: [T]) -> Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }
}

func groupByDate<T: CurrencyConvertible>(_ items: [T], dateKeyPath: KeyPath<T, Date>) -> [TransactionGroup<T>] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: items) { item in
        calendar.startOfDay(for: item[keyPath: dateKeyPath])
    }
    return grouped.sorted { $0.key > $1.key }
        .map { TransactionGroup(date: $0.key, items: $0.value) }
}
