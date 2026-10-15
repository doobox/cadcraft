import Foundation

struct DraftingState: Codable, Sendable {
    let objectSnap: Bool
    let ortho: Bool
    let polar: Bool
    let grid: Bool
    let snap: Bool
    let dynamicInput: Bool
    let objectSnapTracking: Bool
    let gridSpacing: WorldPoint

    static let `default` = DraftingState(
        objectSnap: true,
        ortho: false,
        polar: false,
        grid: false,
        snap: false,
        dynamicInput: true,
        objectSnapTracking: true,
        gridSpacing: WorldPoint(x: 10, y: 10)
    )
}
