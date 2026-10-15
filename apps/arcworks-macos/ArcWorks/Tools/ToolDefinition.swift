import Foundation

struct ToolDefinition: Identifiable, Sendable {
    let command: String
    let label: String
    let icon: ArcWorksIcon

    var id: String { command }
}
