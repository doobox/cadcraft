import SwiftUI

struct ToolButton: View {
    let tool: ToolDefinition
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let action: (ToolDefinition) -> Void

    var body: some View {
        Button {
            action(tool)
        } label: {
            Label {
                Text(tool.label)
            } icon: {
                ArcWorksIconView(tool.icon)
                    .frame(width: iconSize, height: iconSize)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(.rect)
        .help("\(tool.label) — \(tool.command.uppercased())")
    }
}
