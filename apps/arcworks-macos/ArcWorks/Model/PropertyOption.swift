import Foundation

struct PropertyOption: Codable, Identifiable, Sendable {
    let label: String
    let valueJson: String

    var id: String { valueJson }
}
