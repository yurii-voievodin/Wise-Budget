import SwiftUI

struct TransferRowStyle: ViewModifier {
    let isTransfer: Bool

    func body(content: Content) -> some View {
        if isTransfer {
            content
                .foregroundStyle(.secondary)
                .opacity(0.55)
        } else {
            content
        }
    }
}
