import SwiftUI

struct PropertyTextField: View {
    let row: PropertyRow
    let onCommit: (String) -> Void

    @State private var value: String

    init(row: PropertyRow, onCommit: @escaping (String) -> Void) {
        self.row = row
        self.onCommit = onCommit
        _value = State(initialValue: PropertyJSON.string(from: row.valueJson) ?? "")
    }

    var body: some View {
        TextField(row.varies ? "Varies" : row.label, text: $value)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(row.label)
            .onSubmit(commit)
            .onChange(of: row.valueJson, synchronizeValue)
    }

    private func commit() {
        guard let json = PropertyJSON.encode(value), json != row.valueJson else { return }
        onCommit(json)
    }

    private func synchronizeValue() {
        value = PropertyJSON.string(from: row.valueJson) ?? ""
    }
}
