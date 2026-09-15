import SwiftUI

/// Subtle rounded card surface used by Budget Plan rows, Cashflow month
/// cards, and similar grouped tiles. Centralizes the radius and tint so
/// they stay consistent. A non-nil `tint` marks a card that needs attention
/// (e.g. an overspent category) and is drawn slightly stronger.
extension View {
    func cardBackground(cornerRadius: CGFloat = 10, tint: Color? = nil) -> some View {
        background(
            (tint ?? .secondary).opacity(tint == nil ? 0.06 : 0.10),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}
