import SwiftUI

struct StatusUtilityMenu: View {
    let document: DrawingDocument

    var body: some View {
        Menu("Status Bar Settings", systemImage: "gearshape") {
            Button(document.showsToolSidebar ? "Hide Tools" : "Show Tools", action: document.toggleToolSidebar)
            Button(document.showsInspector ? "Hide Inspector" : "Show Inspector", action: document.toggleInspector)
            Button(document.showsCommandHistory ? "Hide Command History" : "Show Command History", action: document.toggleCommandHistory)
            Divider()
            Button("Manage Layers…", systemImage: "square.3.layers.3d", action: document.presentLayerManager)
        }
        .labelStyle(.iconOnly)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: WorkspaceMetrics.statusButtonSize, height: WorkspaceMetrics.statusButtonSize)
        .help("Status Bar Settings")
    }
}
