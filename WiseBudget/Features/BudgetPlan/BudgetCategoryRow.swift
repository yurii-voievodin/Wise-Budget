import SwiftUI

struct BudgetCategoryRow: View {
    let categoryName: String
    let categoryIcon: String
    let actual: Decimal
    let planned: Decimal
    let currency: String
    let onPlannedChange: (Decimal) -> Void
    var onCategoryTap: (() -> Void)?

    private var isUnplannedSpending: Bool {
        BudgetProgressBar.isUnplannedSpending(planned: planned, spent: actual)
    }

    private var isOverspent: Bool {
        isUnplannedSpending || (planned > 0 && actual > planned)
    }

    private var percentText: String {
        guard planned > 0, actual > 0 else { return "—" }
        return (actual / planned).formatted(.percent.precision(.fractionLength(0)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small) {
            HStack(spacing: Layout.Spacing.small) {
                if let onCategoryTap {
                    Button(action: onCategoryTap) {
                        BudgetCategoryLabel(categoryName: categoryName, categoryIcon: categoryIcon)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show expenses for \(categoryName)")
                } else {
                    BudgetCategoryLabel(categoryName: categoryName, categoryIcon: categoryIcon)
                }
                Spacer(minLength: 8)
                Text(actual, format: .number)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(isOverspent ? Color.expense : .primary)
                Text("/")
                    .foregroundStyle(.tertiary)
                PlannedAmountField(
                    value: planned,
                    currency: currency,
                    onChange: onPlannedChange
                )
            }
            HStack(spacing: Layout.Spacing.small) {
                BudgetProgressBar(spent: actual, planned: planned)
                Text(percentText)
                    .font(.caption)
                    .foregroundStyle(isOverspent ? Color.expense : .secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(Layout.Spacing.medium)
        .cardBackground(tint: isOverspent ? .expense : nil)
        .overlay {
            if isOverspent {
                RoundedRectangle(cornerRadius: Layout.Radius.medium)
                    .stroke(Color.expense.opacity(0.35), lineWidth: 1)
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
