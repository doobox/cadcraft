import MetalKit
import simd

@MainActor
final class DrawingMetalView: MTKView {
    var drawingRenderer: MetalRenderer?

    private var snapshot = DrawingSnapshot.empty
    private var cursorFeedback = CursorFeedback.empty
    private var dynamicEntry = ""
    private var lastPanLocation: CGPoint?
    private var selectionStart: CGPoint?
    private var selectionWindow: SelectionWindow?
    private var activeGrip: GripPrimitive?
    private var lastCursorPoint: WorldPoint?
    private var lastCursorShift = false
    private var dwellTask: Task<Void, Never>?
    private var onViewportSizeChanged: ((CGSize) -> Void)?
    private var onPanView: ((CGSize, CGSize) -> Void)?
    private var onZoomView: ((Double, CGPoint, CGSize) -> Void)?
    private var onZoomExtents: (() -> Void)?
    private var onPoint: ((WorldPoint, Bool, CGSize) -> Void)?
    private var onMove: ((WorldPoint, Bool, Double, CGSize, TimeInterval) -> Void)?
    private var onWindow: ((WorldPoint, WorldPoint, Bool, CGSize) -> Void)?
    private var onBeginGrip: ((GripPrimitive) -> Void)?
    private var onDynamicEntryChanged: ((String) -> Void)?
    private var onDynamicSubmit: (() -> Void)?
    private var onBeginCommandEntry: ((String) -> Void)?
    private var onToggleDrafting: ((DraftingSetting) -> Void)?
    private var onEnter: (() -> Void)?
    private var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    func configure(
        snapshot: DrawingSnapshot,
        cursorFeedback: CursorFeedback,
        dynamicEntry: String,
        onViewportSizeChanged: @escaping (CGSize) -> Void,
        onPanView: @escaping (CGSize, CGSize) -> Void,
        onZoomView: @escaping (Double, CGPoint, CGSize) -> Void,
        onZoomExtents: @escaping () -> Void,
        onPoint: @escaping (WorldPoint, Bool, CGSize) -> Void,
        onMove: @escaping (WorldPoint, Bool, Double, CGSize, TimeInterval) -> Void,
        onWindow: @escaping (WorldPoint, WorldPoint, Bool, CGSize) -> Void,
        onBeginGrip: @escaping (GripPrimitive) -> Void,
        onDynamicEntryChanged: @escaping (String) -> Void,
        onDynamicSubmit: @escaping () -> Void,
        onBeginCommandEntry: @escaping (String) -> Void,
        onToggleDrafting: @escaping (DraftingSetting) -> Void,
        onEnter: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.cursorFeedback = cursorFeedback
        self.dynamicEntry = dynamicEntry
        self.onViewportSizeChanged = onViewportSizeChanged
        self.onPanView = onPanView
        self.onZoomView = onZoomView
        self.onZoomExtents = onZoomExtents
        self.onPoint = onPoint
        self.onMove = onMove
        self.onWindow = onWindow
        self.onBeginGrip = onBeginGrip
        self.onDynamicEntryChanged = onDynamicEntryChanged
        self.onDynamicSubmit = onDynamicSubmit
        self.onBeginCommandEntry = onBeginCommandEntry
        self.onToggleDrafting = onToggleDrafting
        self.onEnter = onEnter
        self.onCancel = onCancel
        onViewportSizeChanged(interactionViewportSize)
        scheduleDwellUpdateIfNeeded()
        redraw()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            dwellTask?.cancel()
            dwellTask = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if let grip = grip(at: point) {
            activeGrip = grip
            onBeginGrip?(grip)
            sendCursor(event, at: point)
        } else if snapshot.canWindowSelect {
            selectionStart = point
        } else {
            sendCursor(event, at: point)
            onPoint?(worldPoint(from: point), event.modifierFlags.contains(.shift), interactionViewportSize)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if activeGrip != nil {
            sendCursor(event, at: point)
            return
        }
        guard let selectionStart else { return }
        let distance = hypot(point.x - selectionStart.x, point.y - selectionStart.y)
        guard distance >= 4 else { return }
        selectionWindow = SelectionWindow(start: worldPoint(from: selectionStart), end: worldPoint(from: point))
        redraw()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if activeGrip != nil {
            sendCursor(event, at: point)
            onPoint?(worldPoint(from: point), event.modifierFlags.contains(.shift), interactionViewportSize)
            activeGrip = nil
            return
        }
        guard let selectionStart else { return }
        let start = worldPoint(from: selectionStart)
        let end = worldPoint(from: point)
        if selectionWindow != nil {
            onWindow?(start, end, event.modifierFlags.contains(.shift), interactionViewportSize)
        } else {
            sendCursor(event, at: point)
            onPoint?(end, event.modifierFlags.contains(.shift), interactionViewportSize)
        }
        self.selectionStart = nil
        selectionWindow = nil
        redraw()
    }

    override func mouseMoved(with event: NSEvent) {
        sendCursor(event, at: convert(event.locationInWindow, from: nil))
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        onEnter?()
    }

    override func otherMouseDown(with event: NSEvent) {
        dwellTask?.cancel()
        if event.clickCount == 2 {
            onZoomExtents?()
            return
        }
        lastPanLocation = convert(event.locationInWindow, from: nil)
    }

    override func otherMouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let lastPanLocation else { return }
        onPanView?(
            CGSize(width: location.x - lastPanLocation.x, height: location.y - lastPanLocation.y),
            interactionViewportSize
        )
        self.lastPanLocation = location
    }

    override func otherMouseUp(with event: NSEvent) {
        lastPanLocation = nil
    }

    override func scrollWheel(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if event.hasPreciseScrollingDeltas && !event.modifierFlags.contains(.option) {
            onPanView?(
                CGSize(width: event.scrollingDeltaX, height: -event.scrollingDeltaY),
                interactionViewportSize
            )
        } else {
            let multiplier = Float(exp(Double(event.scrollingDeltaY) * 0.025))
            requestZoom(by: multiplier, around: point)
        }
    }

    override func magnify(with event: NSEvent) {
        let multiplier = Float(max(0.05, 1 + event.magnification))
        let point = convert(event.locationInWindow, from: nil)
        requestZoom(by: multiplier, around: point)
    }

    override func smartMagnify(with event: NSEvent) {
        onZoomExtents?()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:
            if dynamicEntry.isEmpty {
                onEnter?()
            } else {
                onDynamicSubmit?()
            }
        case 53:
            if dynamicEntry.isEmpty {
                onCancel?()
            } else {
                onDynamicEntryChanged?("")
            }
        case 49:
            if snapshot.prompt == "Command:" {
                onEnter?()
            } else if shouldCaptureDynamicInput(event) {
                onDynamicEntryChanged?(dynamicEntry + " ")
            } else {
                super.keyDown(with: event)
            }
        case 51, 117:
            if dynamicEntry.isEmpty {
                super.keyDown(with: event)
            } else {
                onDynamicEntryChanged?(String(dynamicEntry.dropLast()))
            }
        case 99:
            onToggleDrafting?(.objectSnap)
        case 98:
            onToggleDrafting?(.grid)
        case 100:
            onToggleDrafting?(.ortho)
        case 101:
            onToggleDrafting?(.snap)
        case 109:
            onToggleDrafting?(.polar)
        case 103:
            onToggleDrafting?(.objectSnapTracking)
        case 111:
            onToggleDrafting?(.dynamicInput)
        default:
            if shouldCaptureDynamicInput(event), let characters = event.characters {
                onDynamicEntryChanged?(dynamicEntry + characters)
            } else if shouldBeginCommandEntry(event), let characters = event.characters {
                onBeginCommandEntry?(characters)
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func shouldCaptureDynamicInput(_ event: NSEvent) -> Bool {
        guard snapshot.drafting.dynamicInput, snapshot.prompt != "Command:" else { return false }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        return event.characters?.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) } == true
    }

    private func shouldBeginCommandEntry(_ event: NSEvent) -> Bool {
        guard snapshot.prompt == "Command:" else { return false }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        return event.characters?.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains($0)
        } == true
    }

    private func redraw() {
        drawingRenderer?.update(
            snapshot,
            cursorFeedback: cursorFeedback,
            drawableSize: drawableSize,
            worldPerPixel: worldPerPixel(),
            selectionWindow: selectionWindow
        )
        setNeedsDisplay(bounds)
    }

    private func requestZoom(by multiplier: Float, around point: CGPoint) {
        onZoomView?(Double(multiplier), point, interactionViewportSize)
    }

    override func layout() {
        super.layout()
        onViewportSizeChanged?(interactionViewportSize)
    }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .cursorUpdate],
                owner: self
            )
        )
        super.updateTrackingAreas()
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    private func sendCursor(_ event: NSEvent, at point: CGPoint) {
        dwellTask?.cancel()
        let worldPoint = worldPoint(from: point)
        let shift = event.modifierFlags.contains(.shift)
        lastCursorPoint = worldPoint
        lastCursorShift = shift
        onMove?(
            worldPoint,
            shift,
            worldPerPixel(),
            interactionViewportSize,
            event.timestamp
        )
    }

    private func scheduleDwellUpdateIfNeeded() {
        dwellTask?.cancel()
        guard cursorFeedback.trackingWait, lastCursorPoint != nil else {
            dwellTask = nil
            return
        }
        dwellTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            guard !Task.isCancelled, let self, let point = self.lastCursorPoint else { return }
            self.onMove?(
                point,
                self.lastCursorShift,
                self.worldPerPixel(),
                self.interactionViewportSize,
                ProcessInfo.processInfo.systemUptime
            )
        }
    }

    private func worldPerPixel() -> Double {
        let origin = worldPoint(from: .zero)
        let onePixel = worldPoint(from: CGPoint(x: 1, y: 0))
        return Double(hypot(onePixel.x - origin.x, onePixel.y - origin.y))
    }

    private func grip(at point: CGPoint) -> GripPrimitive? {
        let world = worldPoint(from: point)
        let tolerance = Float(worldPerPixel() * 8)
        return snapshot.grips.min { first, second in
            hypot(first.point.x - world.x, first.point.y - world.y) < hypot(second.point.x - world.x, second.point.y - world.y)
        }.flatMap { candidate in
            hypot(candidate.point.x - world.x, candidate.point.y - world.y) <= tolerance ? candidate : nil
        }
    }

    private func worldPoint(from point: CGPoint) -> WorldPoint {
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let ndc = SIMD2(Float(point.x / width * 2 - 1), Float(point.y / height * 2 - 1))
        return ViewTransform(view: snapshot.view, drawableSize: drawableSize).world(ndc)
    }

    private var interactionViewportSize: CGSize {
        CGSize(width: max(bounds.width, 1), height: max(bounds.height, 1))
    }
}
