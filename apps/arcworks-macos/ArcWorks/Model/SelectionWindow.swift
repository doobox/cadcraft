import Foundation

struct SelectionWindow: Sendable {
    let start: WorldPoint
    let end: WorldPoint

    var isCrossing: Bool {
        end.x < start.x
    }
}
