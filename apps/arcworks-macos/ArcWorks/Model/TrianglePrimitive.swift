import Foundation

struct TrianglePrimitive: Codable, Sendable {
    let points: [WorldPoint]
    let color: [Float]
}

