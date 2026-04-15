import Testing
import Foundation
@testable import WiseBudget

struct MonthFilterTests {

    // MARK: - moved(by:)

    @Test func moveForwardOneMonth() {
        let march = MonthFilter(year: 2026, month: 3)
        let april = march.moved(by: 1)
        #expect(april.year == 2026)
        #expect(april.month == 4)
    }

    @Test func moveBackwardOneMonth() {
        let march = MonthFilter(year: 2026, month: 3)
        let february = march.moved(by: -1)
        #expect(february.year == 2026)
        #expect(february.month == 2)
    }

    @Test func moveForwardFromDecemberWrapsYear() {
        let december = MonthFilter(year: 2025, month: 12)
        let january = december.moved(by: 1)
        #expect(january.year == 2026)
        #expect(january.month == 1)
    }

    @Test func moveBackwardFromJanuaryWrapsYear() {
        let january = MonthFilter(year: 2026, month: 1)
        let december = january.moved(by: -1)
        #expect(december.year == 2025)
        #expect(december.month == 12)
    }

    @Test func moveForwardTwelveMonths() {
        let march2026 = MonthFilter(year: 2026, month: 3)
        let march2027 = march2026.moved(by: 12)
        #expect(march2027.year == 2027)
        #expect(march2027.month == 3)
    }

    @Test func moveBackwardTwelveMonths() {
        let march2026 = MonthFilter(year: 2026, month: 3)
        let march2025 = march2026.moved(by: -12)
        #expect(march2025.year == 2025)
        #expect(march2025.month == 3)
    }

    // MARK: - isFutureMonth

    @Test func farFutureMonthIsFuture() {
        let future = MonthFilter(year: 2099, month: 12)
        #expect(future.isFutureMonth == true)
    }

    @Test func distantPastIsNotFuture() {
        let past = MonthFilter(year: 2000, month: 1)
        #expect(past.isFutureMonth == false)
    }

    // MARK: - startOfMonth

    @Test func startOfMonthIsFirstDay() {
        let filter = MonthFilter(year: 2026, month: 3)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: filter.startOfMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 3)
        #expect(comps.day == 1)
    }

    // MARK: - startOfNextMonth

    @Test func startOfNextMonthIsFirstDayOfNextMonth() {
        let filter = MonthFilter(year: 2026, month: 3)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: filter.startOfNextMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 1)
    }

    @Test func startOfNextMonthDecemberWrapsToJanuary() {
        let filter = MonthFilter(year: 2025, month: 12)
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day], from: filter.startOfNextMonth)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 1)
    }

    // MARK: - foreignOnly default

    @Test func foreignOnlyDefaultsToFalse() {
        let filter = MonthFilter(year: 2026, month: 3)
        #expect(filter.foreignOnly == false)
    }
}
