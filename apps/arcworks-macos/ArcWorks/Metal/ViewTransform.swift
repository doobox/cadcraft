import CoreGraphics
import simd

struct ViewTransform {
    private let center: SIMD2<Float>
    private let scale: SIMD2<Float>

    init(view: DrawingViewState, drawableSize: CGSize) {
        let height = max(view.height, 0.000_001)
        let aspect = max(Float(drawableSize.width / max(drawableSize.height, 1)), 0.001)
        center = SIMD2(view.center.x, view.center.y)
        scale = SIMD2(2 / (height * aspect), 2 / height)
    }

    func ndc(_ point: WorldPoint) -> SIMD2<Float> {
        SIMD2((point.x - center.x) * scale.x, (point.y - center.y) * scale.y)
    }

    func world(_ point: SIMD2<Float>) -> WorldPoint {
        WorldPoint(x: point.x / scale.x + center.x, y: point.y / scale.y + center.y)
    }
}

