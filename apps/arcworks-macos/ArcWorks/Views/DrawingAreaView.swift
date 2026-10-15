import SwiftUI

struct DrawingAreaView: View {
    let document: DrawingDocument

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MetalCanvas(
                snapshot: document.snapshot,
                cursorFeedback: document.cursorFeedback,
                dynamicEntry: document.dynamicEntry,
                onViewportSizeChanged: document.updateViewportSize,
                onPanView: document.panView,
                onZoomView: document.zoomView,
                onZoomExtents: document.zoomExtents,
                onPoint: document.submit,
                onMove: document.updateCursor,
                onWindow: document.selectWindow,
                onBeginGrip: document.beginGrip,
                onDynamicEntryChanged: document.updateDynamicEntry,
                onDynamicSubmit: document.submitDynamicEntry,
                onBeginCommandEntry: document.beginCommandEntry,
                onToggleDrafting: document.toggleDrafting,
                onEnter: document.enter,
                onCancel: document.cancel
            )

            if document.snapshot.drafting.dynamicInput {
                DynamicInputView(
                    prompt: document.snapshot.prompt,
                    feedback: document.cursorFeedback,
                    entry: document.dynamicEntry
                )
                .padding(12)
            }
        }
            .background(.black)
            .accessibilityLabel("Drawing canvas")
            .accessibilityValue("Drawing contains \(document.snapshot.entityCount) objects")
    }
}

