import Foundation

struct CursorFeedback: Codable, Sendable {
    let point: WorldPoint
    let snap: String?
    let base: WorldPoint?
    let distance: Float?
    let angleDegrees: Float?
    let strokes: [StrokePrimitive]
    let triangles: [TrianglePrimitive]
    let trackingGuides: [TrackingGuide]
    let acquiredPoints: [AcquiredTrackingPoint]
    let inference: String?
    let trackingCrossing: Bool
    let trackingWait: Bool

    static let empty = CursorFeedback(
        point: WorldPoint(x: 0, y: 0),
        snap: nil,
        base: nil,
        distance: nil,
        angleDegrees: nil,
        strokes: [],
        triangles: [],
        trackingGuides: [],
        acquiredPoints: [],
        inference: nil,
        trackingCrossing: false,
        trackingWait: false
    )
}
