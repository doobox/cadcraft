import Foundation

struct AcquiredTrackingPoint: Codable, Sendable {
    let point: WorldPoint
    let parallel: Bool
}
