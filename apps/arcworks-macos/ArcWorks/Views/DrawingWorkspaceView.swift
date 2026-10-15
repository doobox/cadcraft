import SwiftUI

struct DrawingWorkspaceView: View {
    let document: DrawingDocument

    var body: some View {
        ZStack(alignment: .bottom) {
            DrawingAreaView(document: document)
            CommandBar(document: document)
                .frame(maxWidth: WorkspaceMetrics.commandLineMaximumWidth)
                .padding(.horizontal)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
