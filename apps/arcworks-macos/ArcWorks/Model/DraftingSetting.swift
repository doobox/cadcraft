import Foundation

enum DraftingSetting: String, CaseIterable, Identifiable, Sendable {
    case objectSnap = "osnap"
    case ortho
    case polar
    case grid
    case snap
    case dynamicInput = "dynmode"
    case objectSnapTracking = "otrack"

    var id: Self { self }

    var label: String {
        switch self {
        case .objectSnap: "OSNAP"
        case .ortho: "ORTHO"
        case .polar: "POLAR"
        case .grid: "GRID"
        case .snap: "SNAP"
        case .dynamicInput: "DYN"
        case .objectSnapTracking: "OTRACK"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .objectSnap: "Object Snap"
        case .ortho: "Ortho Mode"
        case .polar: "Polar Tracking"
        case .grid: "Grid Display"
        case .snap: "Snap Mode"
        case .dynamicInput: "Dynamic Input"
        case .objectSnapTracking: "Object Snap Tracking"
        }
    }

    var icon: ArcWorksIcon {
        switch self {
        case .objectSnap: .objectSnap
        case .ortho: .ortho
        case .polar: .polar
        case .grid: .grid
        case .snap: .snap
        case .dynamicInput: .dynamicInput
        case .objectSnapTracking: .objectSnapTracking
        }
    }

    var shortcutLabel: String {
        switch self {
        case .objectSnap: "F3"
        case .grid: "F7"
        case .ortho: "F8"
        case .snap: "F9"
        case .polar: "F10"
        case .objectSnapTracking: "F11"
        case .dynamicInput: "F12"
        }
    }

    func isEnabled(in state: DraftingState) -> Bool {
        switch self {
        case .objectSnap: state.objectSnap
        case .ortho: state.ortho
        case .polar: state.polar
        case .grid: state.grid
        case .snap: state.snap
        case .dynamicInput: state.dynamicInput
        case .objectSnapTracking: state.objectSnapTracking
        }
    }
}
