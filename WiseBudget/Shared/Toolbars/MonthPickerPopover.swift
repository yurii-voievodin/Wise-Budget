import SwiftUI

struct MonthPickerPopover: View {
    @Binding var year: Int
    @Binding var month: Int
    let yearRange: ClosedRange<Int>
    let showsCurrentMonthButton: Bool
    let onGoToCurrentMonth: () -> Void
    let onApply: () -> Void

    private let monthSymbols = Calendar.current.monthSymbols

    var body: some View {
        VStack(spacing: Layout.Spacing.medium) {
            HStack {
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthSymbols[month - 1]).tag(month)
                    }
                }
                .labelsHidden()

                Picker("Year", selection: $year) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .labelsHidden()
            }

            HStack {
                if showsCurrentMonthButton {
                    Button("Current Month", action: onGoToCurrentMonth)
                }

                Button("Go", action: onApply)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
