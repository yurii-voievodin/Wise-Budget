import SwiftUI

struct InsightHintsList: View {
    let hints: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(hints.indices, id: \.self) { index in
                InsightHintRow(text: hints[index])
                if index < hints.count - 1 {
                    Divider()
                        .padding(.leading, 28)
                }
            }
        }
    }
}

#Preview {
    Form {
        Section {
            InsightHintsList(hints: [
                "Hertz repair of 1008.35 was the month's hidden hit, roughly equal to a typical week of spending.",
                "Pulse spans Groceries and Medical at 244.00 across 5 charges — your category split for that merchant is inconsistent.",
                "Savings came in at -84% — the MacBook Pro M5 Pro charges of 1200.69 and 1000.00 drove most of the shortfall.",
            ])
        } header: {
            Label("Monthly Insights", systemImage: "sparkles")
        }
    }
    .formStyle(.grouped)
    .frame(width: 500, height: 400)
}
