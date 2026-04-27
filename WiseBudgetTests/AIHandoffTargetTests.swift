import Testing
import Foundation
@testable import WiseBudget

@MainActor
struct AIHandoffTargetTests {

    @Test func idEncodesProviderAndDestination() {
        #expect(AIHandoffTarget(provider: .claude, destination: .nativeApp).id == "claude-nativeApp")
        #expect(AIHandoffTarget(provider: .chatgpt, destination: .web).id == "chatgpt-web")
    }

    @Test func equalitySplitsByDestination() {
        let nativeClaude = AIHandoffTarget(provider: .claude, destination: .nativeApp)
        let webClaude = AIHandoffTarget(provider: .claude, destination: .web)
        #expect(nativeClaude != webClaude)
    }
}
