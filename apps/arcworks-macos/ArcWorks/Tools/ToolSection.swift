import Foundation

struct ToolSection: Identifiable, Sendable {
    let title: String
    let featuredTools: [ToolDefinition]
    let tools: [ToolDefinition]

    var id: String { title }
}
