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

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 4) {
                Button("Previous Month", systemImage: "chevron.left") {
                    moveMonth(by: -1)
                }
                .labelStyle(.iconOnly)
                Button {
                    pickerYear = year
                    pickerMonth = month
                    isDatePickerPresented.toggle()
                } label: {
                    Text(monthTitle)
                        .font(.headline)
                }
                .popover(isPresented: $isDatePickerPresented) {
                    datePickerPopover
                }
                Button("Next Month", systemImage: "chevron.right") {
                    moveMonth(by: 1)
                }
                .labelStyle(.iconOnly)
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
                Button("Current Month", action: goToCurrentMonth)

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
