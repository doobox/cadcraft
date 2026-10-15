import Foundation

struct PropertyGroup: Codable, Identifiable, Sendable {
    let name: String
    let rows: [PropertyRow]

    var id: String { name }
}
