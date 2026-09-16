import SwiftUI

struct CurrencyOptionRow: View {
    let option: CurrencyOption
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            Text(option.code)
                .font(.system(.body, design: .rounded))
                .bold()
                .frame(minWidth: 42, alignment: .leading)
            Text(option.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: Layout.Spacing.small)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
