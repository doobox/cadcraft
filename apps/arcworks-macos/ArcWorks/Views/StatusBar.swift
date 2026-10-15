import SwiftUI

struct StatusBar: View {
    let document: DrawingDocument

    var body: some View {
        HStack(spacing: 0) {
            if document.showsToolSidebar {
                StatusBarLeadingControls(document: document)
                    .frame(width: WorkspaceMetrics.toolPaletteIdealWidth, alignment: .leading)
            }

            LayoutTabBar(document: document)
                .frame(maxWidth: .infinity, alignment: .leading)

            CoordinateReadout(point: document.cursorFeedback.point)
                .padding(.horizontal, 7)

            Divider()
                .frame(height: 14)

            DrawingScaleMenu(document: document)
                .padding(.horizontal, 5)

            Divider()
                .frame(height: 14)

            DraftingStatusControls(state: document.snapshot.drafting, onToggle: document.toggleDrafting)

            Divider()
                .frame(height: 14)

            StatusUtilityMenu(document: document)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .frame(height: WorkspaceMetrics.statusBarHeight)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

