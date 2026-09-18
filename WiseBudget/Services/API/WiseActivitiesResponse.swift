import Foundation

struct WiseActivitiesResponse: Codable {
    let activities: [WiseActivity]
    let cursor: String?
}
