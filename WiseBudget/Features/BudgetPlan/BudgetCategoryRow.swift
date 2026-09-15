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

    private var categoryLabel: some View {
        HStack(spacing: 8) {
            CategoryIconBadge(
                systemName: categoryIcon,
                color: DefaultExpenseCategory.color(for: categoryName),
                size: 24
            )
            Text(categoryName)
                .fontWeight(.medium)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let onCategoryTap {
                    Button(action: onCategoryTap) {
                        categoryLabel
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Show expenses for \(categoryName)")
                } else {
                    categoryLabel
                }
                Spacer(minLength: 8)
                Text(actual, format: .number)
                    .fontWeight(.semibold)
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
            HStack(spacing: 8) {
                BudgetProgressBar(spent: actual, planned: planned)
                Text(percentText)
                    .font(.caption)
                    .foregroundStyle(isOverspent ? Color.expense : .secondary)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(12)
        .cardBackground(tint: isOverspent ? .expense : nil)
        .overlay {
            if isOverspent {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
