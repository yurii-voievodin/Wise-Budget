import Foundation

struct TransactionGroup<T: CurrencyConvertible>: Identifiable {
    let date: Date
    let items: [T]
    var id: Date { date }
}

func groupByDate<T: CurrencyConvertible>(_ items: [T], dateKeyPath: KeyPath<T, Date>) -> [TransactionGroup<T>] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: items) { item in
        calendar.startOfDay(for: item[keyPath: dateKeyPath])
    }
    return grouped.sorted { $0.key > $1.key }
        .map { TransactionGroup(date: $0.key, items: $0.value) }
}
