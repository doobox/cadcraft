import Foundation

struct PropertyRow: Codable, Identifiable, Sendable {
    let key: String
    let label: String
    let kind: PropertyKind
    let valueJson: String
    let varies: Bool
    let display: String
    let editable: Bool
    let options: [PropertyOption]

    var id: String { key }
}
