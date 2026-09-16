import SwiftUI

struct PlannedAmountField: View {
    let value: Decimal
    let currency: String
    var width: CGFloat = 80
    let onChange: (Decimal) -> Void

    @State private var draft: Decimal?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Layout.Spacing.snug) {
            TextField("0", value: $draft, format: .number)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($isFocused)
                .frame(width: width)
                .padding(.vertical, Layout.Spacing.tight)
                .padding(.horizontal, Layout.Spacing.small)
                .background(
                    .background.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 7)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            isFocused ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.3),
                            lineWidth: 1
                        )
                }
            Text(currency)
                .foregroundStyle(.secondary)
        }
        .onChange(of: draft) { _, newValue in
            let normalized = max(.zero, newValue ?? .zero)
            if normalized != value {
                onChange(normalized)
            }
        }
        .task(id: value) {
            if draft != value {
                draft = value == .zero ? nil : value
            }
        }
    }
}

#Preview {
    @Previewable @State var planned: Decimal = 250
    VStack(alignment: .trailing, spacing: Layout.Spacing.medium) {
        PlannedAmountField(value: planned, currency: "EUR") { planned = $0 }
        PlannedAmountField(value: 0, currency: "USD", width: 120) { _ in }
    }
    .padding()
    .frame(width: 320)
}
