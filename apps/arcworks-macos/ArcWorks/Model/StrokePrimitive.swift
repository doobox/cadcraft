import Foundation

struct StrokePrimitive: Codable, Sendable {
    let points: [WorldPoint]
    let color: [Float]
    let width: Float
}

