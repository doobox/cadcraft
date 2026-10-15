import SwiftUI

struct InspectorView: View {
    let document: DrawingDocument

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Properties")
                    .font(.headline)
                Spacer()
                Button("Hide Properties", systemImage: "chevron.right", action: document.toggleInspector)
                    .labelStyle(.iconOnly)
                    .help("Hide Properties")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                Form {
                    Section("Drawing") {
                        LabeledContent("Name", value: document.snapshot.title)
                        LabeledContent("Objects", value: document.snapshot.entityCount, format: .number)
                        CurrentLayerMenu(layers: document.snapshot.layers, onSelect: document.setCurrentLayer)
                        LabeledContent("Layers", value: document.snapshot.layers.count, format: .number)
                        Button("Manage Layers…", systemImage: "square.3.layers.3d", action: document.presentLayerManager)
                    }
                    SelectionPropertiesView(document: document)
                }
                .formStyle(.columns)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

