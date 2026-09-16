import SwiftUI

struct CashflowSectionPicker: View {
    @Binding var selectedTab: CashflowView.CashflowTab

    var body: some View {
        Picker("Section", selection: $selectedTab) {
            Label("Overview", systemImage: "chart.bar.fill").tag(CashflowView.CashflowTab.overview)
            Label("Expenses", systemImage: "arrow.up.circle.fill").tag(CashflowView.CashflowTab.expenses)
            Label("Income", systemImage: "arrow.down.circle.fill").tag(CashflowView.CashflowTab.income)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
