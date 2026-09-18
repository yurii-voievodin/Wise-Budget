import SwiftUI

struct CashflowTimeRangeMenu: View {
    @Binding var timeRange: CashflowTimeRange

    var body: some View {
        Menu("Time Range", systemImage: "calendar") {
            Picker("Time Range", selection: $timeRange) {
                ForEach(CashflowTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.inline)
        }
        .menuIndicator(.hidden)
        .help("Time Range")
    }
}
