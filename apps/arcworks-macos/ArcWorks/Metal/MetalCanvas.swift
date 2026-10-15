import MetalKit
import SwiftUI

struct MetalCanvas: NSViewRepresentable {
    let snapshot: DrawingSnapshot
    let cursorFeedback: CursorFeedback
    let dynamicEntry: String
    let onViewportSizeChanged: (CGSize) -> Void
    let onPanView: (CGSize, CGSize) -> Void
    let onZoomView: (Double, CGPoint, CGSize) -> Void
    let onZoomExtents: () -> Void
    let onPoint: (WorldPoint, Bool, CGSize) -> Void
    let onMove: (WorldPoint, Bool, Double, CGSize, TimeInterval) -> Void
    let onWindow: (WorldPoint, WorldPoint, Bool, CGSize) -> Void
    let onBeginGrip: (GripPrimitive) -> Void
    let onDynamicEntryChanged: (String) -> Void
    let onDynamicSubmit: () -> Void
    let onBeginCommandEntry: (String) -> Void
    let onToggleDrafting: (DraftingSetting) -> Void
    let onEnter: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> MetalRenderer {
        MetalRenderer()
    }

    func makeNSView(context: Context) -> DrawingMetalView {
        let view = DrawingMetalView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.055, green: 0.063, blue: 0.075, alpha: 1)
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        context.coordinator.attach(to: view)
        view.drawingRenderer = context.coordinator
        return view
    }

    func updateNSView(_ view: DrawingMetalView, context: Context) {
        view.configure(
            snapshot: snapshot,
            cursorFeedback: cursorFeedback,
            dynamicEntry: dynamicEntry,
            onViewportSizeChanged: onViewportSizeChanged,
            onPanView: onPanView,
            onZoomView: onZoomView,
            onZoomExtents: onZoomExtents,
            onPoint: onPoint,
            onMove: onMove,
            onWindow: onWindow,
            onBeginGrip: onBeginGrip,
            onDynamicEntryChanged: onDynamicEntryChanged,
            onDynamicSubmit: onDynamicSubmit,
            onBeginCommandEntry: onBeginCommandEntry,
            onToggleDrafting: onToggleDrafting,
            onEnter: onEnter,
            onCancel: onCancel
        )
    }
}

