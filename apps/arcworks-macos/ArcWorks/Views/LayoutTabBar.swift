import SwiftUI

struct LayoutTabBar: View {
    let document: DrawingDocument

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                LayoutTabButton(
                    name: "Model",
                    isSelected: document.snapshot.currentLayout == "Model",
                    action: { document.selectLayout("Model") }
                )

                Button("Add Layout", systemImage: "plus", action: document.createLayout)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: WorkspaceMetrics.statusButtonSize, height: WorkspaceMetrics.statusBarHeight)
                    .help("Create Layout")

                ForEach(document.snapshot.layouts, id: \.self) { layout in
                    LayoutTabButton(
                        name: layout,
                        isSelected: document.snapshot.currentLayout == layout,
                        action: { document.selectLayout(layout) }
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
