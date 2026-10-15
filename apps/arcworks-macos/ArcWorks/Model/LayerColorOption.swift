import Foundation

enum LayerColorOption: String, CaseIterable, Identifiable, Sendable {
    case red = "1"
    case yellow = "2"
    case green = "3"
    case cyan = "4"
    case blue = "5"
    case magenta = "6"
    case white = "7"

    var id: Self { self }

    var label: String {
        switch self {
        case .red: "Red"
        case .yellow: "Yellow"
        case .green: "Green"
        case .cyan: "Cyan"
        case .blue: "Blue"
        case .magenta: "Magenta"
        case .white: "White"
        }
    }
}
