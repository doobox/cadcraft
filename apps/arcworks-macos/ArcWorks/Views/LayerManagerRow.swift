import AppKit
import SwiftUI

struct LayerManagerRow: View {
    let layer: LayerSummary
    let isSelected: Bool
    let linetypes: [String]
    let onSelect: () -> Void
    let onMakeCurrent: (LayerSummary) -> Void
    let onRename: (LayerSummary, String) -> Void
    let onSetColor: (LayerSummary, String) -> Void
    let onToggleVisibility: (LayerSummary) -> Void
    let onToggleFrozen: (LayerSummary) -> Void
    let onToggleLocked: (LayerSummary) -> Void
    let onTogglePlot: (LayerSummary) -> Void
    let onSetLinetype: (LayerSummary, String) -> Void
    let onSetLineweight: (LayerSummary, String) -> Void
    let onSetTransparency: (LayerSummary, Int) -> Void
    let onSetPlotStyle: (LayerSummary, String) -> Void
    let showsViewportOverrides: Bool
    let onToggleViewportFrozen: (LayerSummary) -> Void
    let onSetViewportColor: (LayerSummary, String) -> Void
    let onClearViewportColor: (LayerSummary) -> Void
    let onToggleNewViewportFrozen: (LayerSummary) -> Void
    let onSetDescription: (LayerSummary, String) -> Void

    @State private var editedName: String
    @State private var editedDescription: String
    @State private var editedPlotStyle: String
    @State private var editedTransparency: Int
    @State private var customColor: Color
    @State private var showsCustomColor = false
    @State private var customViewportColor: Color
    @State private var showsCustomViewportColor = false

    init(
        layer: LayerSummary,
        isSelected: Bool,
        linetypes: [String],
        onSelect: @escaping () -> Void,
        onMakeCurrent: @escaping (LayerSummary) -> Void,
        onRename: @escaping (LayerSummary, String) -> Void,
        onSetColor: @escaping (LayerSummary, String) -> Void,
        onToggleVisibility: @escaping (LayerSummary) -> Void,
        onToggleFrozen: @escaping (LayerSummary) -> Void,
        onToggleLocked: @escaping (LayerSummary) -> Void,
        onTogglePlot: @escaping (LayerSummary) -> Void,
        onSetLinetype: @escaping (LayerSummary, String) -> Void,
        onSetLineweight: @escaping (LayerSummary, String) -> Void,
        onSetTransparency: @escaping (LayerSummary, Int) -> Void,
        onSetPlotStyle: @escaping (LayerSummary, String) -> Void,
        showsViewportOverrides: Bool,
        onToggleViewportFrozen: @escaping (LayerSummary) -> Void,
        onSetViewportColor: @escaping (LayerSummary, String) -> Void,
        onClearViewportColor: @escaping (LayerSummary) -> Void,
        onToggleNewViewportFrozen: @escaping (LayerSummary) -> Void,
        onSetDescription: @escaping (LayerSummary, String) -> Void
    ) {
        self.layer = layer
        self.isSelected = isSelected
        self.linetypes = linetypes
        self.onSelect = onSelect
        self.onMakeCurrent = onMakeCurrent
        self.onRename = onRename
        self.onSetColor = onSetColor
        self.onToggleVisibility = onToggleVisibility
        self.onToggleFrozen = onToggleFrozen
        self.onToggleLocked = onToggleLocked
        self.onTogglePlot = onTogglePlot
        self.onSetLinetype = onSetLinetype
        self.onSetLineweight = onSetLineweight
        self.onSetTransparency = onSetTransparency
        self.onSetPlotStyle = onSetPlotStyle
        self.showsViewportOverrides = showsViewportOverrides
        self.onToggleViewportFrozen = onToggleViewportFrozen
        self.onSetViewportColor = onSetViewportColor
        self.onClearViewportColor = onClearViewportColor
        self.onToggleNewViewportFrozen = onToggleNewViewportFrozen
        self.onSetDescription = onSetDescription
        _editedName = State(initialValue: layer.name)
        _editedDescription = State(initialValue: layer.description)
        _editedPlotStyle = State(initialValue: layer.plotStyle)
        _editedTransparency = State(initialValue: layer.transparency)
        _customColor = State(initialValue: Self.color(from: layer.colorHex))
        _customViewportColor = State(initialValue: Self.color(from: layer.viewportColorHex ?? layer.colorHex))
    }

    var body: some View {
        HStack(spacing: 0) {
            statusButton.frame(width: LayerManagerColumn.status)
            TextField("Layer name", text: $editedName)
                .textFieldStyle(.plain)
                .onSubmit { onRename(layer, editedName) }
                .frame(width: LayerManagerColumn.name, alignment: .leading)
            stateButton(layer.on ? "lightbulb.fill" : "lightbulb.slash", help: layer.on ? "Turn off" : "Turn on") { onToggleVisibility(layer) }
            stateButton(layer.frozen ? "snowflake.circle.fill" : "snowflake", help: layer.frozen ? "Thaw" : "Freeze", disabled: layer.current) { onToggleFrozen(layer) }
            stateButton(layer.locked ? "lock.fill" : "lock.open", help: layer.locked ? "Unlock" : "Lock") { onToggleLocked(layer) }
            stateButton(layer.plot ? "printer.fill" : "printer.slash", help: layer.plot ? "Do not plot" : "Plot") { onTogglePlot(layer) }
            colorMenu.frame(width: LayerManagerColumn.color)
            Menu(layer.linetype) {
                ForEach(linetypes, id: \.self) { name in Button(name) { onSetLinetype(layer, name) } }
            }
            .menuStyle(.borderlessButton)
            .frame(width: LayerManagerColumn.linetype)
            Menu(layer.lineweight) {
                ForEach(Self.lineweights, id: \.self) { value in
                    Button(Self.lineweightLabel(value)) { onSetLineweight(layer, value) }
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: LayerManagerColumn.lineweight)
            Stepper(value: $editedTransparency, in: 0...90, step: 5) {
                Text("\(editedTransparency)%").monospacedDigit()
            }
            .onChange(of: editedTransparency) { _, value in onSetTransparency(layer, value) }
            .frame(width: LayerManagerColumn.transparency)
            TextField("Plot style", text: $editedPlotStyle)
                .textFieldStyle(.plain)
                .onSubmit { onSetPlotStyle(layer, editedPlotStyle) }
                .frame(width: LayerManagerColumn.plotStyle)
            if showsViewportOverrides {
                stateButton(layer.viewportFrozen == true ? "snowflake.circle.fill" : "snowflake", help: "Freeze in current viewport") {
                    onToggleViewportFrozen(layer)
                }
                .frame(width: LayerManagerColumn.viewportFreeze)
                viewportColorMenu.frame(width: LayerManagerColumn.viewportColor)
            }
            stateButton(layer.newViewportFrozen ? "snowflake.circle.fill" : "snowflake", help: "Freeze in new viewports") {
                onToggleNewViewportFrozen(layer)
            }
            .frame(width: LayerManagerColumn.newViewport)
            TextField("Description", text: $editedDescription)
                .textFieldStyle(.plain)
                .onSubmit { onSetDescription(layer, editedDescription) }
                .frame(width: LayerManagerColumn.description, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .frame(height: 30)
        .background(isSelected ? Color.blue.opacity(0.18) : Color.clear)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded(onSelect))
        .onChange(of: layer.name) { _, value in editedName = value }
        .onChange(of: layer.description) { _, value in editedDescription = value }
        .onChange(of: layer.plotStyle) { _, value in editedPlotStyle = value }
        .onChange(of: layer.transparency) { _, value in editedTransparency = value }
    }

    private var statusButton: some View {
        Button { onMakeCurrent(layer) } label: {
            Image(systemName: layer.current ? "checkmark.circle.fill" : (layer.used ? "circle.fill" : "circle"))
                .foregroundStyle(layer.current ? Color.blue : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(layer.current || layer.frozen)
        .help(layer.current ? "Current layer" : (layer.used ? "Used layer — make current" : "Unused layer — make current"))
    }

    private var colorMenu: some View {
        Menu {
            ForEach(LayerColorOption.allCases) { color in
                Button(color.label) { onSetColor(layer, color.rawValue) }
            }
            Divider()
            Button("Custom Colour…") { showsCustomColor = true }
        } label: {
            HStack(spacing: 5) {
                LayerColorSwatch(hex: layer.colorHex)
                Text(layer.colorName).lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .popover(isPresented: $showsCustomColor) {
            VStack(alignment: .leading, spacing: 12) {
                ColorPicker("Layer colour", selection: $customColor, supportsOpacity: false)
                HStack {
                    Button("Cancel") { showsCustomColor = false }
                    Spacer()
                    Button("Apply") {
                        onSetColor(layer, Self.hex(from: customColor))
                        showsCustomColor = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 250)
        }
    }

    private var viewportColorMenu: some View {
        Menu {
            Button("Use Layer Colour") { onClearViewportColor(layer) }
            Divider()
            ForEach(LayerColorOption.allCases) { color in
                Button(color.label) { onSetViewportColor(layer, color.rawValue) }
            }
            Divider()
            Button("Custom Colour…") { showsCustomViewportColor = true }
        } label: {
            HStack(spacing: 5) {
                LayerColorSwatch(hex: layer.viewportColorHex ?? layer.colorHex)
                Text(layer.viewportColorName ?? "ByLayer").lineLimit(1)
            }
        }
        .menuStyle(.borderlessButton)
        .popover(isPresented: $showsCustomViewportColor) {
            VStack(alignment: .leading, spacing: 12) {
                ColorPicker("Viewport colour", selection: $customViewportColor, supportsOpacity: false)
                HStack {
                    Button("Cancel") { showsCustomViewportColor = false }
                    Spacer()
                    Button("Apply") {
                        onSetViewportColor(layer, Self.hex(from: customViewportColor))
                        showsCustomViewportColor = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .frame(width: 250)
        }
    }

    private func stateButton(_ symbol: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: LayerManagerColumn.state)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }

    private static let lineweights = [
        "Default", "0.00", "0.05", "0.09", "0.13", "0.15", "0.18", "0.20", "0.25", "0.30", "0.35", "0.40",
        "0.50", "0.53", "0.60", "0.70", "0.80", "0.90", "1.00", "1.06", "1.20", "1.40", "1.58", "2.00", "2.11"
    ]

    private static func lineweightLabel(_ value: String) -> String { value == "Default" ? value : "\(value) mm" }

    private static func color(from hex: String) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return .white }
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    private static func hex(from color: Color) -> String {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return "#ffffff" }
        return String(
            format: "#%02X%02X%02X",
            Int((converted.redComponent * 255).rounded()),
            Int((converted.greenComponent * 255).rounded()),
            Int((converted.blueComponent * 255).rounded())
        )
    }
}

struct LayerManagerTableHeader: View {
    let sortsDescending: Bool
    let showsViewportOverrides: Bool
    let toggleSort: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Status").frame(width: LayerManagerColumn.status)
            Button(action: toggleSort) {
                HStack(spacing: 4) {
                    Text("Name")
                    Image(systemName: sortsDescending ? "chevron.down" : "chevron.up")
                }
            }
            .buttonStyle(.plain)
            .frame(width: LayerManagerColumn.name, alignment: .leading)
            Text("On").frame(width: LayerManagerColumn.state)
            Text("Freeze").frame(width: LayerManagerColumn.state)
            Text("Lock").frame(width: LayerManagerColumn.state)
            Text("Plot").frame(width: LayerManagerColumn.state)
            Text("Colour").frame(width: LayerManagerColumn.color)
            Text("Linetype").frame(width: LayerManagerColumn.linetype)
            Text("Lineweight").frame(width: LayerManagerColumn.lineweight)
            Text("Transparency").frame(width: LayerManagerColumn.transparency)
            Text("Plot Style").frame(width: LayerManagerColumn.plotStyle)
            if showsViewportOverrides {
                Text("VP Freeze").frame(width: LayerManagerColumn.viewportFreeze)
                Text("VP Colour").frame(width: LayerManagerColumn.viewportColor)
            }
            Text("New VP Freeze").frame(width: LayerManagerColumn.newViewport)
            Text("Description").frame(width: LayerManagerColumn.description, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .frame(height: 30)
        .background(.bar)
    }
}

private enum LayerManagerColumn {
    static let status: CGFloat = 50
    static let name: CGFloat = 170
    static let state: CGFloat = 52
    static let color: CGFloat = 105
    static let linetype: CGFloat = 120
    static let lineweight: CGFloat = 110
    static let transparency: CGFloat = 115
    static let plotStyle: CGFloat = 105
    static let viewportFreeze: CGFloat = 80
    static let viewportColor: CGFloat = 105
    static let newViewport: CGFloat = 100
    static let description: CGFloat = 210
}
