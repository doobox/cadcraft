import SwiftUI

struct SelectionPropertiesView: View {
    let document: DrawingDocument

    var body: some View {
        if document.snapshot.selectionCount == 0 {
            ContentUnavailableView(
                "Nothing Selected",
                systemImage: "cursorarrow.click",
                description: Text("Click an object in the drawing to inspect it.")
            )
        } else {
            Section("Selection") {
                LabeledContent("Objects", value: document.snapshot.selectionCount, format: .number)
                ForEach(document.snapshot.selectionTypes) { type in
                    LabeledContent(type.name, value: type.count, format: .number)
                }
            }

            ForEach(document.snapshot.propertyGroups) { group in
                Section(group.name) {
                    ForEach(group.rows) { row in
                        PropertyRowView(row: row, document: document)
                    }
                }
            }
        }
    }
}
