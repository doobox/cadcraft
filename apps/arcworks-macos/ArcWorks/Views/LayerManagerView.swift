import SwiftUI

struct LayerManagerView: View {
    @Bindable var document: DrawingDocument
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLayerName: String?
    @State private var searchText = ""
    @State private var showsUsedLayersOnly = false
    @State private var sortsDescending = false
    @State private var newLayerName = ""
    @State private var selectedLayerState = ""
    @State private var newLayerStateName = ""
    @State private var confirmsDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            controls
            Divider()
            HStack(spacing: 0) {
                filterSidebar
                Divider()
                layerTable
            }
            Divider()
            footer
        }
        .frame(minWidth: 980, idealWidth: 1_220, minHeight: 540, idealHeight: 680)
        .onAppear(perform: selectInitialLayer)
        .onChange(of: document.snapshot.layers) { _, layers in
            if let selectedLayerName, !layers.contains(where: { $0.name == selectedLayerName }) {
                self.selectedLayerName = layers.first(where: \.current)?.name ?? layers.first?.name
            }
        }
        .confirmationDialog(
            "Delete layer “\(selectedLayerName ?? "")”?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Layer", role: .destructive, action: deleteSelectedLayer)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Only an unused, non-current layer can be deleted.")
        }
    }

    private var header: some View {
        HStack {
            Text("Layer Properties Manager")
                .font(.title2.bold())
            Text("\(document.snapshot.layers.count) layers")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done", action: dismiss.callAsFunction)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("New Layer", systemImage: "plus", action: createAutomaticLayer)
            Button("Delete Layer", systemImage: "minus", role: .destructive) { confirmsDelete = true }
                .disabled(!canDeleteSelectedLayer)
            Button("Set Current", systemImage: "checkmark.circle", action: makeSelectedLayerCurrent)
                .disabled(selectedLayer?.current != false || selectedLayer?.frozen == true)
            Divider().frame(height: 20)
            Picker("Layer State", selection: $selectedLayerState) {
                Text("No saved state").tag("")
                ForEach(document.snapshot.layerStates, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 170)
            Button("Restore", action: restoreSelectedState).disabled(selectedLayerState.isEmpty)
            Button("Delete State", systemImage: "trash", role: .destructive, action: deleteSelectedState)
                .labelStyle(.iconOnly)
                .disabled(selectedLayerState.isEmpty)
            TextField("New state name", text: $newLayerStateName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
                .onSubmit(saveLayerState)
            Button("Save State", action: saveLayerState).disabled(trimmedNewStateName.isEmpty)
            Button("Rename State", action: renameSelectedState)
                .disabled(selectedLayerState.isEmpty || trimmedNewStateName.isEmpty)
            Spacer(minLength: 8)
            TextField("Search layers", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 190)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal)
        .padding(.vertical, 9)
    }

    private var filterSidebar: some View {
        List {
            Section("Filters") {
                Button { showsUsedLayersOnly = false } label: {
                    Label("All", systemImage: showsUsedLayersOnly ? "circle" : "checkmark.circle.fill")
                }
                Button { showsUsedLayersOnly = true } label: {
                    Label("All Used", systemImage: showsUsedLayersOnly ? "checkmark.circle.fill" : "circle")
                }
            }
            Section("Status") {
                LabeledContent("Used", value: "\(document.snapshot.layers.count(where: \.used))")
                LabeledContent("Visible", value: "\(document.snapshot.layers.count { $0.on && !$0.frozen })")
                LabeledContent("Locked", value: "\(document.snapshot.layers.count(where: \.locked))")
            }
        }
        .listStyle(.sidebar)
        .frame(width: 170)
    }

    private var layerTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(filteredLayers) { layer in
                        LayerManagerRow(
                            layer: layer,
                            isSelected: selectedLayerName == layer.name,
                            linetypes: document.snapshot.linetypes,
                            onSelect: { selectedLayerName = layer.name },
                            onMakeCurrent: document.setCurrentLayer,
                            onRename: renameLayer,
                            onSetColor: document.setLayerColor,
                            onToggleVisibility: document.toggleLayerVisibility,
                            onToggleFrozen: document.toggleLayerFrozen,
                            onToggleLocked: document.toggleLayerLocked,
                            onTogglePlot: document.toggleLayerPlot,
                            onSetLinetype: document.setLayerLinetype,
                            onSetLineweight: document.setLayerLineweight,
                            onSetTransparency: document.setLayerTransparency,
                            onSetPlotStyle: document.setLayerPlotStyle,
                            showsViewportOverrides: document.snapshot.hasActiveViewport,
                            onToggleViewportFrozen: document.toggleLayerViewportFrozen,
                            onSetViewportColor: document.setLayerViewportColor,
                            onClearViewportColor: document.clearLayerViewportColor,
                            onToggleNewViewportFrozen: document.toggleLayerNewViewportFrozen,
                            onSetDescription: document.setLayerDescription
                        )
                        Divider()
                    }
                } header: {
                    LayerManagerTableHeader(
                        sortsDescending: sortsDescending,
                        showsViewportOverrides: document.snapshot.hasActiveViewport
                    ) { sortsDescending.toggle() }
                }
            }
        }
        .accessibilityLabel("Drawing layers")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            TextField("New layer name", text: $newLayerName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 230)
                .onSubmit(createNamedLayer)
            Button("Add Layer", systemImage: "plus", action: createNamedLayer)
                .disabled(trimmedNewLayerName.isEmpty)
            Divider().frame(height: 20)
            Menu("Load Linetype", systemImage: "line.3.horizontal") {
                let unloaded = document.snapshot.linetypeLibrary.filter { !document.snapshot.linetypes.contains($0) }
                if unloaded.isEmpty {
                    Text("All standard linetypes are loaded")
                } else {
                    ForEach(unloaded, id: \.self) { name in
                        Button(name) { document.loadLinetype(named: name) }
                    }
                    Divider()
                    Button("Load All") { document.loadLinetype(named: "*") }
                }
            }
            Spacer()
            if let selectedLayer {
                Text(selectedLayer.used ? "Layer is in use" : "Unused layer")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var filteredLayers: [LayerSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return document.snapshot.layers
            .filter { !showsUsedLayersOnly || $0.used }
            .filter { query.isEmpty || wildcardMatch($0.name, pattern: query) || $0.description.localizedCaseInsensitiveContains(query) }
            .sorted {
                sortsDescending
                    ? $0.name.localizedStandardCompare($1.name) == .orderedDescending
                    : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var selectedLayer: LayerSummary? { document.snapshot.layers.first { $0.name == selectedLayerName } }

    private var canDeleteSelectedLayer: Bool {
        guard let selectedLayer else { return false }
        return !selectedLayer.current && !selectedLayer.used && selectedLayer.name != "0"
    }

    private var trimmedNewLayerName: String { newLayerName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNewStateName: String { newLayerStateName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func selectInitialLayer() {
        selectedLayerName = document.snapshot.layers.first(where: \.current)?.name ?? document.snapshot.layers.first?.name
        selectedLayerState = document.snapshot.layerStates.first ?? ""
    }

    private func createAutomaticLayer() {
        let names = Set(document.snapshot.layers.map { $0.name.lowercased() })
        let name = (1...).lazy.map { "Layer\($0)" }.first { !names.contains($0.lowercased()) } ?? "New Layer"
        document.createLayer(named: name)
        selectedLayerName = name
    }

    private func createNamedLayer() {
        guard !trimmedNewLayerName.isEmpty else { return }
        document.createLayer(named: trimmedNewLayerName)
        selectedLayerName = trimmedNewLayerName
        newLayerName = ""
    }

    private func renameLayer(_ layer: LayerSummary, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != layer.name else { return }
        document.renameLayer(layer, to: trimmed)
        selectedLayerName = trimmed
    }

    private func deleteSelectedLayer() {
        guard canDeleteSelectedLayer, let selectedLayer else { return }
        document.deleteLayer(selectedLayer)
    }

    private func makeSelectedLayerCurrent() {
        guard let selectedLayer else { return }
        document.setCurrentLayer(selectedLayer)
    }

    private func saveLayerState() {
        guard !trimmedNewStateName.isEmpty else { return }
        document.saveLayerState(named: trimmedNewStateName)
        selectedLayerState = trimmedNewStateName
        newLayerStateName = ""
    }

    private func restoreSelectedState() {
        guard !selectedLayerState.isEmpty else { return }
        document.restoreLayerState(named: selectedLayerState)
    }

    private func deleteSelectedState() {
        guard !selectedLayerState.isEmpty else { return }
        document.deleteLayerState(named: selectedLayerState)
        selectedLayerState = ""
    }

    private func renameSelectedState() {
        guard !selectedLayerState.isEmpty, !trimmedNewStateName.isEmpty else { return }
        let oldName = selectedLayerState
        document.renameLayerState(named: oldName, to: trimmedNewStateName)
        selectedLayerState = trimmedNewStateName
        newLayerStateName = ""
    }

    private func wildcardMatch(_ text: String, pattern: String) -> Bool {
        guard pattern.contains("*") || pattern.contains("?") else { return text.localizedCaseInsensitiveContains(pattern) }
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        return text.range(of: "^\(escaped)$", options: [.regularExpression, .caseInsensitive]) != nil
    }
}
