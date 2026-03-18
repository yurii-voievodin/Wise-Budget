import SwiftUI

struct MonthNavigationToolbar: ToolbarContent {
    @Binding var year: Int
    @Binding var month: Int

    @State private var isDatePickerPresented = false
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())

    private var monthTitle: String {
        let comps = DateComponents(year: year, month: month, day: 1)
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(.dateTime.month(.wide).year())
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 4) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button {
                    pickerYear = year
                    pickerMonth = month
                    isDatePickerPresented.toggle()
                } label: {
                    Text(monthTitle)
                        .font(.headline)
                }
                .popover(isPresented: $isDatePickerPresented) {
                    VStack(spacing: 12) {
                        HStack {
                            Picker("Month", selection: $pickerMonth) {
                                ForEach(1...12, id: \.self) { m in
                                    Text(Calendar.current.monthSymbols[m - 1]).tag(m)
                                }
                            }
                            .labelsHidden()

                            Picker("Year", selection: $pickerYear) {
                                ForEach((2020...2030), id: \.self) { y in
                                    Text(String(y)).tag(y)
                                }
                            }
                            .labelsHidden()
                        }

                        HStack {
                            Button("Current Month") {
                                let now = Calendar.current.dateComponents([.year, .month], from: Date())
                                year = now.year ?? year
                                month = now.month ?? month
                                isDatePickerPresented = false
                            }

                            Button("Go") {
                                year = pickerYear
                                month = pickerMonth
                                isDatePickerPresented = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
    }

    private func moveMonth(by delta: Int) {
        let comps = DateComponents(year: year, month: month + delta)
        let date = Calendar.current.date(from: comps) ?? Date()
        let newComps = Calendar.current.dateComponents([.year, .month], from: date)
        year = newComps.year ?? year
        month = newComps.month ?? month
    }
}
