import Foundation

struct SelectionType: Codable, Identifiable, Sendable {
    let name: String
    let count: Int

    var id: String { name }
}
