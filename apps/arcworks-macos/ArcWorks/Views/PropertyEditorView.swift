import SwiftUI

struct PropertyEditorView: View {
    let row: PropertyRow
    let document: DrawingDocument

    var body: some View {
        switch row.kind {
        case .text, .contents:
            PropertyTextField(row: row, onCommit: commit)
        case .number, .distance, .angle:
            PropertyNumberField(row: row, onCommit: commit)
        case .bool:
            PropertyChoiceMenu(row: row, options: boolOptions, onSelect: commit)
        case .choice, .textStyle, .dimStyle:
            PropertyChoiceMenu(row: row, options: row.options, onSelect: commit)
        case .color:
            PropertyChoiceMenu(row: row, options: colorOptions, onSelect: commit)
        case .layer:
            PropertyChoiceMenu(row: row, options: layerOptions, onSelect: commit)
        case .linetype:
            PropertyChoiceMenu(row: row, options: linetypeOptions, onSelect: commit)
        case .lineweight:
            PropertyChoiceMenu(row: row, options: lineweightOptions, onSelect: commit)
        case .transparency:
            PropertyChoiceMenu(row: row, options: transparencyOptions, onSelect: commit)
        }
    }

    private var boolOptions: [PropertyOption] {
        [
            PropertyOption(label: "Yes", valueJson: "true"),
            PropertyOption(label: "No", valueJson: "false")
        ]
    }

    private var colorOptions: [PropertyOption] {
        [
            PropertyOption(label: "ByLayer", valueJson: "256"),
            PropertyOption(label: "ByBlock", valueJson: "0"),
            PropertyOption(label: "Red", valueJson: "1"),
            PropertyOption(label: "Yellow", valueJson: "2"),
            PropertyOption(label: "Green", valueJson: "3"),
            PropertyOption(label: "Cyan", valueJson: "4"),
            PropertyOption(label: "Blue", valueJson: "5"),
            PropertyOption(label: "Magenta", valueJson: "6"),
            PropertyOption(label: "White", valueJson: "7")
        ]
    }

    private var layerOptions: [PropertyOption] {
        document.snapshot.layers
            .filter { !$0.frozen && $0.on }
            .compactMap { layer in
                PropertyJSON.encode(layer.name).map { PropertyOption(label: layer.name, valueJson: $0) }
            }
    }

    private var linetypeOptions: [PropertyOption] {
        (["ByLayer", "ByBlock"] + document.snapshot.linetypes)
            .reduce(into: [String]()) { names, name in
                if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                    names.append(name)
                }
            }
            .compactMap { name in
                PropertyJSON.encode(name).map { PropertyOption(label: name, valueJson: $0) }
            }
    }

    private var lineweightOptions: [PropertyOption] {
        ["ByLayer", "ByBlock", "Default"].compactMap { name in
            PropertyJSON.encode(name).map { PropertyOption(label: name, valueJson: $0) }
        } + [0.00, 0.05, 0.09, 0.13, 0.18, 0.25, 0.35, 0.50, 0.70, 1.00, 1.40, 2.00].map { value in
            PropertyOption(label: value.formatted(.number.precision(.fractionLength(2))) + " mm", valueJson: value.description)
        }
    }

    private var transparencyOptions: [PropertyOption] {
        ["ByLayer", "ByBlock"].compactMap { name in
            PropertyJSON.encode(name).map { PropertyOption(label: name, valueJson: $0) }
        } + stride(from: 0, through: 90, by: 10).map { value in
            PropertyOption(label: "\(value)%", valueJson: value.description)
        }
    }

    private func commit(_ valueJson: String) {
        document.setSelectionProperty(row, valueJson: valueJson)
    }
}
