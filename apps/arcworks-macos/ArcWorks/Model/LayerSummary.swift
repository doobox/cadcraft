import Foundation

struct LayerSummary: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let colorName: String
    let colorHex: String
    let on: Bool
    let frozen: Bool
    let locked: Bool
    let plot: Bool
    let linetype: String
    let lineweight: String
    let transparency: Int
    let description: String
    let plotStyle: String
    let newViewportFrozen: Bool
    let viewportFrozen: Bool?
    let viewportColorName: String?
    let viewportColorHex: String?
    let used: Bool
    let current: Bool

    var id: String { name }
}
