import SwiftUI

struct BudgetCategoryRow: View {
    let categoryName: String
    let categoryIcon: String
    let actual: Decimal
    let planned: Decimal
    let currency: String
    let onPlannedChange: (Decimal) -> Void
    var onCategoryTap: (() -> Void)?

    @State private var draftPlanned: Decimal?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let onCategoryTap {
                    Button(action: onCategoryTap) {
                        Label(categoryName, systemImage: categoryIcon)
                            .fontWeight(.medium)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show expenses for \(categoryName)")
                } else {
                    Label(categoryName, systemImage: categoryIcon)
                        .fontWeight(.medium)
                }
                Spacer()
                Text(actual, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("/")
                    .foregroundStyle(.secondary)
                TextField("0", value: $draftPlanned, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    }
                    .onChange(of: draftPlanned) { _, newValue in
                        let normalized = max(.zero, newValue ?? .zero)
                        if normalized != planned {
                            onPlannedChange(normalized)
                        }
                    }
                Text(currency)
                    .foregroundStyle(.secondary)
            }
            if actual > 0, planned > 0 {
                HStack {
                    BudgetProgressBar(spent: actual, planned: planned)
                    Text(actual / planned, format: .percent.precision(.fractionLength(0)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .task(id: planned) {
            // Sync the draft from the source of truth when a different
            // category's value changes propagate, or on first appearance.
            if draftPlanned != planned {
                draftPlanned = planned == .zero ? nil : planned
            }
        }
    }
}

#Preview("Light") {
    BudgetCategoryRowPreviewSamples()
        .frame(width: 500, height: 360)
}

#Preview("Dark") {
    BudgetCategoryRowPreviewSamples()
        .frame(width: 500, height: 360)
        .preferredColorScheme(.dark)
}

private struct BudgetCategoryRowPreviewSamples: View {
    var body: some View {
        List {
            BudgetCategoryRow(
                categoryName: "Groceries",
                categoryIcon: "cart",
                actual: 320,
                planned: 500,
                currency: "USD",
                onPlannedChange: { _ in }
            )
            BudgetCategoryRow(
                categoryName: "Transport",
                categoryIcon: "car",
                actual: 0,
                planned: 200,
                currency: "USD",
                onPlannedChange: { _ in }
            )
            BudgetCategoryRow(
                categoryName: "Entertainment",
                categoryIcon: "film",
                actual: 150,
                planned: 100,
                currency: "USD",
                onPlannedChange: { _ in }
            )
            BudgetCategoryRow(
                categoryName: "Coffee (unplanned)",
                categoryIcon: "cup.and.saucer",
                actual: 42,
                planned: 0,
                currency: "USD",
                onPlannedChange: { _ in }
            )
        }
    }
}
