import SwiftUI

struct MonthNavigationToolbar: ToolbarContent {
    @Binding var year: Int
    @Binding var month: Int

    @State private var isDatePickerPresented = false
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date.now)
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date.now)

    private var monthTitle: String {
        let comps = DateComponents(year: year, month: month, day: 1)
        let date = Calendar.current.date(from: comps) ?? Date.now
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var yearRange: ClosedRange<Int> {
        let currentYear = Calendar.current.component(.year, from: Date.now)
        return (currentYear - 6)...(currentYear + 4)
    }

    private var monthSymbols: [String] {
        Calendar.current.monthSymbols
    }

    private var isOnCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date.now)
        return now.year == year && now.month == month
    }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Previous Month", systemImage: "chevron.left") {
                moveMonth(by: -1)
            }
            .help("Previous Month")
            Button("Next Month", systemImage: "chevron.right") {
                moveMonth(by: 1)
            }
            .help("Next Month")
        }
        ToolbarItem(placement: .status) {
            Button {
                pickerYear = year
                pickerMonth = month
                isDatePickerPresented.toggle()
            } label: {
                Text(monthTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
            }
            .popover(isPresented: $isDatePickerPresented) {
                datePickerPopover
            }
        }
    }

    private var datePickerPopover: some View {
        let symbols = monthSymbols
        return VStack(spacing: 12) {
            HStack {
                Picker("Month", selection: $pickerMonth) {
                    ForEach(1...12, id: \.self) { m in
                        Text(symbols[m - 1]).tag(m)
                    }
                }
                .labelsHidden()

                Picker("Year", selection: $pickerYear) {
                    ForEach(yearRange, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .labelsHidden()
            }

            HStack {
                if !isOnCurrentMonth {
                    Button("Current Month", action: goToCurrentMonth)
                }

                Button("Go", action: applyPickedDate)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func goToCurrentMonth() {
        let now = Calendar.current.dateComponents([.year, .month], from: Date.now)
        year = now.year ?? year
        month = now.month ?? month
        isDatePickerPresented = false
    }

    private func applyPickedDate() {
        year = pickerYear
        month = pickerMonth
        isDatePickerPresented = false
    }

    private func moveMonth(by delta: Int) {
        let comps = DateComponents(year: year, month: month + delta)
        let date = Calendar.current.date(from: comps) ?? Date.now
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        year = newComps.year ?? year
        month = newComps.month ?? month
    }
}
