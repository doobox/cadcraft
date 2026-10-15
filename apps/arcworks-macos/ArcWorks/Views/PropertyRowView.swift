import SwiftUI

struct PropertyRowView: View {
    let row: PropertyRow
    let document: DrawingDocument

    var body: some View {
        LabeledContent(row.label) {
            if row.editable {
                PropertyEditorView(row: row, document: document)
            } else {
                Text(row.display)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }
}
