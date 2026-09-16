import SwiftUI

enum Motion {
    static let standard = Animation.easeInOut(duration: 0.2)
    static let settle = Animation.easeOut(duration: 0.2)
    static let hover = Animation.easeOut(duration: 0.12)
}
