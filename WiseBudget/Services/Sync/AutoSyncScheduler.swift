import Foundation

/// Gates automatic sync attempts to at most once per interval, persisted across launches.
struct AutoSyncScheduler {
    private static let lastAttemptKey = "autoSyncLastAttemptDate"
    private static let interval: TimeInterval = 3600

    static func isDue() -> Bool {
        let lastAttempt = UserDefaults.standard.double(forKey: lastAttemptKey)
        return Date.now.timeIntervalSince1970 - lastAttempt >= interval
    }

    static func recordAttempt() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: lastAttemptKey)
    }
}
