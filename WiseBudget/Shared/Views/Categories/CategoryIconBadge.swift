import SwiftUI

struct CategoryIconBadge: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                color.opacity(0.18),
                in: RoundedRectangle(cornerRadius: size * 0.28)
            )
    }
}
