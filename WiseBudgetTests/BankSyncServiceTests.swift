import Testing
import Foundation
@testable import WiseBudget

struct BankSyncServiceTests {
    private func clearCursor(for bank: Bank) {
        UserDefaults.standard.removeObject(forKey: bank.syncedUpToKey)
    }

    @Test func noCursorFallsBackToRequestedStart() {
        clearCursor(for: .wise)
        defer { clearCursor(for: .wise) }

        let requestedStart = Date(timeIntervalSince1970: 1_000_000)
        let result = BankSyncService.incrementalStart(for: .wise, requestedStart: requestedStart)

        #expect(result == requestedStart)
    }

    @Test func recentCursorResumesWithOverlap() {
        clearCursor(for: .monobank)
        defer { clearCursor(for: .monobank) }

        let requestedStart = Date(timeIntervalSince1970: 1_000_000)
        let syncedUpTo = requestedStart.addingTimeInterval(10 * 24 * 60 * 60) // 10 days into the month
        UserDefaults.standard.set(syncedUpTo.timeIntervalSince1970, forKey: Bank.monobank.syncedUpToKey)

        let result = BankSyncService.incrementalStart(for: .monobank, requestedStart: requestedStart)

        // Resumes 3 days before the cursor, not from the month start.
        let expected = syncedUpTo.addingTimeInterval(-3 * 24 * 60 * 60)
        #expect(result == expected)
        #expect(result > requestedStart)
    }

    @Test func staleCursorFromAPastMonthDoesNotSkipTheNewMonth() {
        clearCursor(for: .wise)
        defer { clearCursor(for: .wise) }

        // Cursor left over from syncing March; now syncing April from scratch.
        let marchEnd = Date(timeIntervalSince1970: 1_000_000)
        UserDefaults.standard.set(marchEnd.timeIntervalSince1970, forKey: Bank.wise.syncedUpToKey)

        let aprilStart = marchEnd.addingTimeInterval(30 * 24 * 60 * 60)
        let result = BankSyncService.incrementalStart(for: .wise, requestedStart: aprilStart)

        #expect(result == aprilStart)
    }
}
