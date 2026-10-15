import SwiftUI

struct CurrentLayerMenu: View {
    let layers: [LayerSummary]
    let onSelect: (LayerSummary) -> Void

    var body: some View {
        Menu {
            ForEach(layers) { layer in
                Button {
                    onSelect(layer)
                } label: {
                    Label(layer.name, systemImage: layer.current ? "checkmark" : statusSymbol(for: layer))
                }
                .disabled(layer.frozen)
            }
        } label: {
            LabeledContent("Current layer") {
                if let currentLayer {
                    Label {
                        Text(currentLayer.name)
                    } icon: {
                        LayerColorSwatch(hex: currentLayer.colorHex)
                    }
                } else {
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .accessibilityHint("Choose the layer used for new objects")
    }

    private var currentLayer: LayerSummary? {
        layers.first(where: \.current)
    }

    private func statusSymbol(for layer: LayerSummary) -> String {
        if layer.frozen { return "snowflake" }
        if !layer.on { return "lightbulb.slash" }
        if layer.locked { return "lock" }
        return "circle"
    }
}
