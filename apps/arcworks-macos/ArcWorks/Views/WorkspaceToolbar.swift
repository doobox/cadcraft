import SwiftUI

struct WorkspaceToolbar: ToolbarContent {
    let document: DrawingDocument

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("New Drawing", systemImage: "doc", action: document.newDrawing)
            Button("Open Drawing", systemImage: "folder", action: document.openDrawing)
            Button("Save Drawing", systemImage: "square.and.arrow.down", action: document.saveDrawing)
            Button("Undo", systemImage: "arrow.uturn.backward", action: document.undo)
                .disabled(document.snapshot.undoLabel == nil)
            Button("Redo", systemImage: "arrow.uturn.forward", action: document.redo)
                .disabled(document.snapshot.redoLabel == nil)
        }
        ToolbarItemGroup(placement: .automatic) {
            Button("Zoom Extents", systemImage: "arrow.up.left.and.arrow.down.right", action: document.zoomExtents)
            Button(action: document.presentLayerManager) {
                Label {
                    Text("Layer Manager")
                } icon: {
                    ArcWorksIconView(.layers)
                        .frame(width: 18, height: 18)
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button("Toggle Inspector", systemImage: "sidebar.right", action: document.toggleInspector)
        }
    }
}

