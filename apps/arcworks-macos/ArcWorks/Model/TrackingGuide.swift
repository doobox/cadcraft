import Foundation

struct TrackingGuide: Codable, Sendable {
    let points: [WorldPoint]
    let kind: String
}
