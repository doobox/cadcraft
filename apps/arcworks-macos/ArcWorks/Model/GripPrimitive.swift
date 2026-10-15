import Foundation

struct GripPrimitive: Codable, Sendable {
    let handle: String
    let index: Int
    let point: WorldPoint
}
