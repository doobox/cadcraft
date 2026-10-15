import SwiftUI

struct PropertyNumberField: View {
    let row: PropertyRow
    let onCommit: (String) -> Void

    @State private var value: Double?

    init(row: PropertyRow, onCommit: @escaping (String) -> Void) {
        self.row = row
        self.onCommit = onCommit
        _value = State(initialValue: PropertyJSON.number(from: row.valueJson))
    }

    var body: some View {
        TextField(
            row.varies ? "Varies" : row.label,
            value: $value,
            format: .number.precision(.fractionLength(0...6))
        )
        .labelsHidden()
        .multilineTextAlignment(.trailing)
        .accessibilityLabel(row.label)
        .onSubmit(commit)
        .onChange(of: row.valueJson, synchronizeValue)
    }

    private func commit() {
        guard let value, value.isFinite, let json = PropertyJSON.encode(value), json != row.valueJson else { return }
        onCommit(json)
    }

    private func synchronizeValue() {
        value = PropertyJSON.number(from: row.valueJson)
    }
}
