import SwiftUI

struct ToolSidebar: View {
    let document: DrawingDocument

    var body: some View {
        VStack(spacing: 0) {
            Text("Tools")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(ToolCatalog.sections) { section in
                        ToolSectionView(section: section, action: run)
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        //.background(.bar)
    }

    private func run(_ tool: ToolDefinition) {
        document.activateTool(tool.command)
    }
}
