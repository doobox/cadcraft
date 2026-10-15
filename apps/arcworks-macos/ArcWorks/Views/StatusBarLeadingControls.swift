import SwiftUI

struct StatusBarLeadingControls: View {
    let document: DrawingDocument

    var body: some View {
        HStack(spacing: 2) {
            Button("New Drawing", systemImage: "plus", action: document.newDrawing)
                .labelStyle(.iconOnly)
                .help("New Drawing")

            Menu("Drawing Menu", systemImage: "line.3.horizontal") {
                Button("New Drawing", systemImage: "doc", action: document.newDrawing)
                Button("Open Drawing…", systemImage: "folder", action: document.openDrawing)
                Button("Save Drawing", systemImage: "square.and.arrow.down", action: document.saveDrawing)
                Divider()
                Button("Manage Layers…", systemImage: "square.3.layers.3d", action: document.presentLayerManager)
            }
            .labelStyle(.iconOnly)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Drawing Menu")
        }
        .buttonStyle(.plain)
        .controlSize(.small)
        .padding(.horizontal, 4)
    }
}
