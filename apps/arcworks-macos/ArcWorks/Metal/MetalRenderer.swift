import MetalKit
import simd

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var vertices: [MetalVertex] = []
    private var strokes: [StrokeDraw] = []
    private var triangleVertexCount = 0
    private var snapshot = DrawingSnapshot.empty
    private var cursorFeedback = CursorFeedback.empty
    private var worldPerPixel: Double = 1
    private var selectionWindow: SelectionWindow?

    func attach(to view: MTKView) {
        guard let device = view.device else { return }
        commandQueue = device.makeCommandQueue()
        pipeline = makePipeline(device: device, pixelFormat: view.colorPixelFormat)
        view.delegate = self
    }

    func update(
        _ snapshot: DrawingSnapshot,
        cursorFeedback: CursorFeedback,
        drawableSize: CGSize,
        worldPerPixel: Double = 1,
        selectionWindow: SelectionWindow? = nil
    ) {
        self.snapshot = snapshot
        self.cursorFeedback = cursorFeedback
        self.worldPerPixel = worldPerPixel
        self.selectionWindow = selectionWindow
        let transform = ViewTransform(view: snapshot.view, drawableSize: drawableSize)
        var newVertices: [MetalVertex] = []
        var newStrokes: [StrokeDraw] = []

        for triangle in snapshot.triangles {
            let color = vectorColor(triangle.color)
            newVertices.append(contentsOf: triangle.points.map { MetalVertex(position: transform.ndc($0), color: color) })
        }
        for triangle in cursorFeedback.triangles {
            let color = vectorColor(triangle.color)
            newVertices.append(contentsOf: triangle.points.map { MetalVertex(position: transform.ndc($0), color: color) })
        }
        if let selectionWindow {
            let minX = min(selectionWindow.start.x, selectionWindow.end.x)
            let maxX = max(selectionWindow.start.x, selectionWindow.end.x)
            let minY = min(selectionWindow.start.y, selectionWindow.end.y)
            let maxY = max(selectionWindow.start.y, selectionWindow.end.y)
            let corners = [
                WorldPoint(x: minX, y: minY),
                WorldPoint(x: maxX, y: minY),
                WorldPoint(x: maxX, y: maxY),
                WorldPoint(x: minX, y: maxY),
            ]
            let fillColor = selectionWindow.isCrossing
                ? SIMD4<Float>(0.25, 0.78, 0.43, 0.16)
                : SIMD4<Float>(0.20, 0.50, 1.00, 0.16)
            for index in [0, 1, 2, 0, 2, 3] {
                newVertices.append(MetalVertex(position: transform.ndc(corners[index]), color: fillColor))
            }
        }
        triangleVertexCount = newVertices.count

        if snapshot.drafting.grid {
            appendGrid(transform: transform, vertices: &newVertices, strokes: &newStrokes)
        }

        let inferenceColor = SIMD4<Float>(0.2, 0.95, 1, 0.9)
        for guide in cursorFeedback.trackingGuides where guide.points.count > 1 {
            appendDashedPolyline(
                guide.points,
                color: inferenceColor,
                transform: transform,
                vertices: &newVertices,
                strokes: &newStrokes
            )
        }
        for acquired in cursorFeedback.acquiredPoints {
            appendAcquiredMarker(
                acquired,
                color: inferenceColor,
                transform: transform,
                vertices: &newVertices,
                strokes: &newStrokes
            )
        }
        if cursorFeedback.trackingCrossing {
            appendCrossingMarker(
                at: cursorFeedback.point,
                color: inferenceColor,
                transform: transform,
                vertices: &newVertices,
                strokes: &newStrokes
            )
        }

        for stroke in snapshot.strokes + cursorFeedback.strokes where stroke.points.count > 1 {
            let start = newVertices.count
            let color = vectorColor(stroke.color)
            newVertices.append(contentsOf: stroke.points.map { MetalVertex(position: transform.ndc($0), color: color) })
            newStrokes.append(StrokeDraw(range: start..<newVertices.count))
        }

        if cursorFeedback.snap != nil {
            let radius = Float(max(worldPerPixel, 0.000_001) * 6)
            let point = cursorFeedback.point
            let marker = [
                WorldPoint(x: point.x, y: point.y + radius),
                WorldPoint(x: point.x + radius, y: point.y),
                WorldPoint(x: point.x, y: point.y - radius),
                WorldPoint(x: point.x - radius, y: point.y),
                WorldPoint(x: point.x, y: point.y + radius),
            ]
            let start = newVertices.count
            let color = SIMD4<Float>(0.2, 0.95, 1, 1)
            newVertices.append(contentsOf: marker.map { MetalVertex(position: transform.ndc($0), color: color) })
            newStrokes.append(StrokeDraw(range: start..<newVertices.count))
        }

        for grip in snapshot.grips {
            let radius = Float(max(worldPerPixel, 0.000_001) * 5)
            let point = grip.point
            let marker = [
                WorldPoint(x: point.x - radius, y: point.y - radius),
                WorldPoint(x: point.x + radius, y: point.y - radius),
                WorldPoint(x: point.x + radius, y: point.y + radius),
                WorldPoint(x: point.x - radius, y: point.y + radius),
                WorldPoint(x: point.x - radius, y: point.y - radius),
            ]
            let start = newVertices.count
            let color = SIMD4<Float>(0.2, 0.72, 1, 1)
            newVertices.append(contentsOf: marker.map { MetalVertex(position: transform.ndc($0), color: color) })
            newStrokes.append(StrokeDraw(range: start..<newVertices.count))
        }

        if let selectionWindow {
            let borderColor = selectionWindow.isCrossing
                ? SIMD4<Float>(0.32, 0.90, 0.50, 1)
                : SIMD4<Float>(0.30, 0.62, 1.00, 1)
            let corners = [
                selectionWindow.start,
                WorldPoint(x: selectionWindow.end.x, y: selectionWindow.start.y),
                selectionWindow.end,
                WorldPoint(x: selectionWindow.start.x, y: selectionWindow.end.y),
                selectionWindow.start,
            ]
            if selectionWindow.isCrossing {
                let dashLength = Float(max(worldPerPixel, 0.000_001) * 7)
                for index in corners.indices.dropLast() {
                    let first = corners[index]
                    let last = corners[index + 1]
                    let length = hypot(last.x - first.x, last.y - first.y)
                    let count = max(Int(ceil(length / dashLength)), 1)
                    for dashIndex in stride(from: 0, to: count, by: 2) {
                        let startFraction = Float(dashIndex) / Float(count)
                        let endFraction = Float(min(dashIndex + 1, count)) / Float(count)
                        let points = [startFraction, endFraction].map { fraction in
                            WorldPoint(
                                x: first.x + (last.x - first.x) * fraction,
                                y: first.y + (last.y - first.y) * fraction
                            )
                        }
                        let start = newVertices.count
                        newVertices.append(contentsOf: points.map { MetalVertex(position: transform.ndc($0), color: borderColor) })
                        newStrokes.append(StrokeDraw(range: start..<newVertices.count))
                    }
                }
            } else {
                let start = newVertices.count
                newVertices.append(contentsOf: corners.map { MetalVertex(position: transform.ndc($0), color: borderColor) })
                newStrokes.append(StrokeDraw(range: start..<newVertices.count))
            }
        }

        vertices = newVertices
        strokes = newStrokes
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        update(
            snapshot,
            cursorFeedback: cursorFeedback,
            drawableSize: size,
            worldPerPixel: worldPerPixel,
            selectionWindow: selectionWindow
        )
        view.setNeedsDisplay(view.bounds)
    }

    func draw(in view: MTKView) {
        guard
            !vertices.isEmpty,
            let device = view.device,
            let commandQueue,
            let pipeline,
            let pass = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass),
            let buffer = device.makeBuffer(bytes: vertices, length: MemoryLayout<MetalVertex>.stride * vertices.count)
        else { return }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        if triangleVertexCount > 0 {
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triangleVertexCount)
        }
        for stroke in strokes {
            encoder.drawPrimitives(type: .lineStrip, vertexStart: stroke.range.lowerBound, vertexCount: stroke.range.count)
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct Vertex { float2 position; float4 color; };
        struct Raster { float4 position [[position]]; float4 color; };
        vertex Raster vertex_main(const device Vertex *vertices [[buffer(0)]], uint id [[vertex_id]]) {
            Raster out;
            out.position = float4(vertices[id].position, 0.0, 1.0);
            out.color = vertices[id].color;
            return out;
        }
        fragment float4 fragment_main(Raster in [[stage_in]]) { return in.color; }
        """
        guard
            let library = try? device.makeLibrary(source: source, options: nil),
            let vertex = library.makeFunction(name: "vertex_main"),
            let fragment = library.makeFunction(name: "fragment_main")
        else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func vectorColor(_ components: [Float]) -> SIMD4<Float> {
        guard components.count == 4 else { return SIMD4(1, 1, 1, 1) }
        return SIMD4(components[0], components[1], components[2], components[3])
    }

    private func appendDashedPolyline(
        _ points: [WorldPoint],
        color: SIMD4<Float>,
        transform: ViewTransform,
        vertices: inout [MetalVertex],
        strokes: inout [StrokeDraw]
    ) {
        let dashLength = Float(max(worldPerPixel, 0.000_001) * 6)
        let gapLength = Float(max(worldPerPixel, 0.000_001) * 4)
        let period = dashLength + gapLength
        var travelled: Float = 0

        for index in points.indices.dropLast() {
            let first = points[index]
            let last = points[index + 1]
            let deltaX = last.x - first.x
            let deltaY = last.y - first.y
            let length = hypot(deltaX, deltaY)
            guard length.isFinite, length > 0, period.isFinite, period > 0 else { continue }

            let segmentStart = travelled
            let segmentEnd = segmentStart + length
            let firstCycle = Int(floor(segmentStart / period))
            let lastCycle = Int(ceil(segmentEnd / period))
            let boundedLastCycle = min(lastCycle, firstCycle + 4_096)
            if firstCycle <= boundedLastCycle {
                for cycle in firstCycle...boundedLastCycle {
                    let dashStart = Float(cycle) * period
                    let overlapStart = max(segmentStart, dashStart)
                    let overlapEnd = min(segmentEnd, dashStart + dashLength)
                    guard overlapEnd > overlapStart else { continue }
                    let fractions = [(overlapStart - segmentStart) / length, (overlapEnd - segmentStart) / length]
                    let segment = fractions.map { fraction in
                        WorldPoint(x: first.x + deltaX * fraction, y: first.y + deltaY * fraction)
                    }
                    appendStroke(segment, color: color, transform: transform, vertices: &vertices, strokes: &strokes)
                }
            }
            travelled = segmentEnd
        }
    }

    private func appendAcquiredMarker(
        _ acquired: AcquiredTrackingPoint,
        color: SIMD4<Float>,
        transform: ViewTransform,
        vertices: inout [MetalVertex],
        strokes: inout [StrokeDraw]
    ) {
        let radius = Float(max(worldPerPixel, 0.000_001) * 5)
        let point = acquired.point
        if acquired.parallel {
            appendStroke(
                [WorldPoint(x: point.x - radius, y: point.y + radius * 0.6), WorldPoint(x: point.x - radius * 0.2, y: point.y - radius)],
                color: color,
                transform: transform,
                vertices: &vertices,
                strokes: &strokes
            )
            appendStroke(
                [WorldPoint(x: point.x + radius * 0.2, y: point.y + radius * 0.6), WorldPoint(x: point.x + radius, y: point.y - radius)],
                color: color,
                transform: transform,
                vertices: &vertices,
                strokes: &strokes
            )
        } else {
            appendStroke(
                [WorldPoint(x: point.x - radius, y: point.y), WorldPoint(x: point.x + radius, y: point.y)],
                color: color,
                transform: transform,
                vertices: &vertices,
                strokes: &strokes
            )
            appendStroke(
                [WorldPoint(x: point.x, y: point.y - radius), WorldPoint(x: point.x, y: point.y + radius)],
                color: color,
                transform: transform,
                vertices: &vertices,
                strokes: &strokes
            )
        }
    }

    private func appendCrossingMarker(
        at point: WorldPoint,
        color: SIMD4<Float>,
        transform: ViewTransform,
        vertices: inout [MetalVertex],
        strokes: inout [StrokeDraw]
    ) {
        let radius = Float(max(worldPerPixel, 0.000_001) * 5)
        appendStroke(
            [WorldPoint(x: point.x - radius, y: point.y - radius), WorldPoint(x: point.x + radius, y: point.y + radius)],
            color: color,
            transform: transform,
            vertices: &vertices,
            strokes: &strokes
        )
        appendStroke(
            [WorldPoint(x: point.x + radius, y: point.y - radius), WorldPoint(x: point.x - radius, y: point.y + radius)],
            color: color,
            transform: transform,
            vertices: &vertices,
            strokes: &strokes
        )
    }

    private func appendStroke(
        _ points: [WorldPoint],
        color: SIMD4<Float>,
        transform: ViewTransform,
        vertices: inout [MetalVertex],
        strokes: inout [StrokeDraw]
    ) {
        let start = vertices.count
        vertices.append(contentsOf: points.map { MetalVertex(position: transform.ndc($0), color: color) })
        strokes.append(StrokeDraw(range: start..<vertices.count))
    }

    private func appendGrid(transform: ViewTransform, vertices: inout [MetalVertex], strokes: inout [StrokeDraw]) {
        let lower = transform.world(SIMD2(-1, -1))
        let upper = transform.world(SIMD2(1, 1))
        let visibleWidth = max(upper.x - lower.x, 0.001)
        let visibleHeight = max(upper.y - lower.y, 0.001)
        let requestedX = max(snapshot.drafting.gridSpacing.x, Float(worldPerPixel) * 8)
        let requestedY = max(snapshot.drafting.gridSpacing.y, Float(worldPerPixel) * 8)
        let stepX = requestedX * max(ceil(visibleWidth / requestedX / 100), 1)
        let stepY = requestedY * max(ceil(visibleHeight / requestedY / 100), 1)
        let minor = SIMD4<Float>(0.35, 0.39, 0.44, 0.24)
        let axis = SIMD4<Float>(0.52, 0.57, 0.64, 0.52)

        for x in stride(from: floor(lower.x / stepX) * stepX, through: upper.x, by: stepX) {
            let start = vertices.count
            let color = abs(x) < stepX * 0.01 ? axis : minor
            let points = [WorldPoint(x: x, y: lower.y), WorldPoint(x: x, y: upper.y)]
            vertices.append(contentsOf: points.map { MetalVertex(position: transform.ndc($0), color: color) })
            strokes.append(StrokeDraw(range: start..<vertices.count))
        }
        for y in stride(from: floor(lower.y / stepY) * stepY, through: upper.y, by: stepY) {
            let start = vertices.count
            let color = abs(y) < stepY * 0.01 ? axis : minor
            let points = [WorldPoint(x: lower.x, y: y), WorldPoint(x: upper.x, y: y)]
            vertices.append(contentsOf: points.map { MetalVertex(position: transform.ndc($0), color: color) })
            strokes.append(StrokeDraw(range: start..<vertices.count))
        }
    }
}

