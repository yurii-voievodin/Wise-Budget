import SwiftUI

/// Subtle rounded card surface used by Budget Plan rows, Cashflow month
/// cards, and similar grouped tiles. Centralizes the radius and tint so
/// they stay consistent.
extension View {
    func cardBackground(cornerRadius: CGFloat = 10) -> some View {
        background(
            Color.secondary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// Strips the row chrome off a `Form`/`List` row so an inner grid of
    /// self-styled cards can float without an extra section background.
    func flatListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
