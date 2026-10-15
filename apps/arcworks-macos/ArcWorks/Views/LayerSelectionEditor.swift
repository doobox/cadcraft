import SwiftUI

struct LayerSelectionEditor: View {
    let layer: LayerSummary
    @Binding var renameName: String
    let onRename: (LayerSummary, String) -> Void
    let onSetColor: (LayerSummary, LayerColorOption) -> Void
    let onDelete: (LayerSummary) -> Void

    @State private var confirmsDelete = false

    var body: some View {
        GroupBox("Selected Layer") {
            HStack {
                TextField("Layer name", text: $renameName)
                    .onSubmit(rename)
                Button("Rename", action: rename)
                    .disabled(renameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || renameName == layer.name)

                Menu("Colour", systemImage: "paintpalette") {
                    ForEach(LayerColorOption.allCases) { color in
                        Button(color.label) {
                            onSetColor(layer, color)
                        }
                    }
                }

                Button("Delete", systemImage: "trash", role: .destructive) {
                    confirmsDelete = true
                }
                .disabled(layer.current || layer.name == "0")
                .confirmationDialog(
                    "Delete layer “\(layer.name)” ?",
                    isPresented: $confirmsDelete,
                    titleVisibility: .visible
                ) {
                    Button("Delete Layer", role: .destructive) {
                        onDelete(layer)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Only unused layers can be deleted. This cannot be undone after the drawing is saved.")
                }
            }
        }
    }

    private func rename() {
        onRename(layer, renameName)
    }
}
