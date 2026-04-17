import Testing
@testable import WiseBudget

@MainActor
struct InsightLocaleTests {

    @Test func ukrainianLocaleAndUkrainianModelPicksUkrainian() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: "uk",
            modelSupportedCodes: ["en", "uk"]
        )
        #expect(resolved.identifier == "uk")
        #expect(resolved.monthlyInstructions.contains("українською"))
    }

    @Test func ukrainianLocaleWithoutModelSupportFallsBackToEnglish() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: "uk",
            modelSupportedCodes: ["en"]
        )
        #expect(resolved.identifier == "en")
        #expect(resolved.monthlyInstructions.contains("concise personal-finance analyst"))
    }

    @Test func englishLocalePicksEnglish() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: "en",
            modelSupportedCodes: ["en", "uk"]
        )
        #expect(resolved.identifier == "en")
    }

    @Test func unknownLocalePicksEnglish() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: nil,
            modelSupportedCodes: ["en", "uk"]
        )
        #expect(resolved.identifier == "en")
    }

    @Test func polishLocalePicksEnglish() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: "pl",
            modelSupportedCodes: ["en", "pl", "uk"]
        )
        #expect(resolved.identifier == "en")
    }

    @Test func trendsAndMonthlyInstructionsDifferInSameLocale() {
        let resolved = InsightLocale.resolve(
            userLanguageCode: "en",
            modelSupportedCodes: ["en"]
        )
        #expect(resolved.monthlyInstructions != resolved.trendsInstructions)
    }
}
