import Foundation

enum LayerAction: String, Sendable {
    case create = "new"
    case rename
    case color
    case delete
    case toggleOn
    case toggleFrozen
    case toggleLocked
    case togglePlot
    case linetype
    case lineweight
    case transparency
    case description
    case plotStyle
    case toggleNewViewportFrozen
    case loadLinetype
    case saveState
    case restoreState
    case deleteState
    case renameState
    case viewportColor
    case clearViewportColor
    case toggleViewportFrozen
}
