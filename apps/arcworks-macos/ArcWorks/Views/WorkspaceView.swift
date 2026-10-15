import SwiftUI

struct WorkspaceView: View {
    @Bindable var document: DrawingDocument
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                ToolSidebar(document: document)
                    .navigationSplitViewColumnWidth(
                        min: WorkspaceMetrics.toolPaletteMinimumWidth,
                        ideal: WorkspaceMetrics.toolPaletteIdealWidth,
                        max: WorkspaceMetrics.toolPaletteMaximumWidth
                    )
            } detail: {
                DrawingWorkspaceView(document: document)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationSplitViewStyle(.balanced)
            .inspector(isPresented: $document.showsInspector) {
                InspectorView(document: document)
                    .inspectorColumnWidth(
                        min: WorkspaceMetrics.inspectorMinimumWidth,
                        ideal: WorkspaceMetrics.inspectorIdealWidth,
                        max: WorkspaceMetrics.inspectorMaximumWidth
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBar(document: document)
        }
        .navigationTitle(document.snapshot.dirty ? "\(document.snapshot.title) — Edited" : document.snapshot.title)
        .toolbar {
            WorkspaceToolbar(document: document)
        }
        .toolbarRole(.editor)
        .sheet(isPresented: $document.showsLayerManager) {
            LayerManagerView(document: document)
        }
        .sheet(isPresented: $document.showsDrawingRecovery) {
            DrawingRecoveryView(document: document)
        }
        .task {
            await document.runAutosaveLoop()
        }
        .onChange(of: document.showsToolSidebar) { _, isVisible in
            columnVisibility = isVisible ? .all : .detailOnly
        }
        .onChange(of: columnVisibility) { _, visibility in
            document.showsToolSidebar = visibility != .detailOnly
        }
        .alert(
            "ArcWorks",
            isPresented: $document.isPresentingError,
            presenting: document.presentedError
        ) { _ in
            Button("OK", action: document.dismissError)
        } message: { error in
            Text(error.localizedDescription)
        }
    }
}

#Preview {
    WorkspaceView(document: DrawingDocument())
        .frame(width: 1100, height: 720)
}

