import Foundation

enum PropertyKind: String, Codable, Sendable {
    case text
    case contents
    case number
    case distance
    case angle
    case bool
    case choice
    case color
    case layer
    case linetype
    case lineweight
    case transparency
    case textStyle
    case dimStyle
}
