import SwiftUI

struct ArcWorksIconPainter {
    var context: GraphicsContext
    let size: CGSize
    let base: Color
    let accent: Color
    let pointColor: Color

    private var scale: CGFloat { min(size.width, size.height) / 24 }
    private var origin: CGPoint {
        CGPoint(x: (size.width - 24 * scale) / 2, y: (size.height - 24 * scale) / 2)
    }
    private var lineWidth: CGFloat { min(max(min(size.width, size.height) / 16, 1), 1.6) }

    private func location(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    mutating func line(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double, color: Color? = nil) {
        var path = Path()
        path.move(to: location(x1, y1))
        path.addLine(to: location(x2, y2))
        context.stroke(path, with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func polyline(_ points: [(Double, Double)], closed: Bool = false, color: Color? = nil) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: location(first.0, first.1))
        for point in points.dropFirst() {
            path.addLine(to: location(point.0, point.1))
        }
        if closed { path.closeSubpath() }
        context.stroke(path, with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func circle(_ x: Double, _ y: Double, radius: Double, color: Color? = nil) {
        let center = location(x, y)
        let rect = CGRect(x: center.x - radius * scale, y: center.y - radius * scale, width: radius * scale * 2, height: radius * scale * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func ellipse(_ x: Double, _ y: Double, radiusX: Double, radiusY: Double, color: Color? = nil) {
        let center = location(x, y)
        let rect = CGRect(
            x: center.x - radiusX * scale,
            y: center.y - radiusY * scale,
            width: radiusX * scale * 2,
            height: radiusY * scale * 2
        )
        context.stroke(Path(ellipseIn: rect), with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func filledCircle(_ x: Double, _ y: Double, radius: Double, color: Color? = nil) {
        let center = location(x, y)
        let rect = CGRect(x: center.x - radius * scale, y: center.y - radius * scale, width: radius * scale * 2, height: radius * scale * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color ?? pointColor))
    }

    mutating func rectangle(_ x: Double, _ y: Double, width: Double, height: Double, color: Color? = nil) {
        let rect = CGRect(x: location(x, y).x, y: location(x, y).y, width: width * scale, height: height * scale)
        context.stroke(Path(rect), with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func filledRectangle(_ x: Double, _ y: Double, width: Double, height: Double, color: Color) {
        let rect = CGRect(x: location(x, y).x, y: location(x, y).y, width: width * scale, height: height * scale)
        context.fill(Path(rect), with: .color(color))
    }

    mutating func gradientRectangle(_ x: Double, _ y: Double, width: Double, height: Double) {
        let start = location(x, y)
        let end = location(x + width, y)
        let rect = CGRect(x: start.x, y: start.y, width: width * scale, height: height * scale)
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [accent.opacity(0.2), accent, Color(nsColor: .systemIndigo)]),
                startPoint: start,
                endPoint: end
            )
        )
    }

    mutating func arc(_ x: Double, _ y: Double, radius: Double, start: Double, end: Double, color: Color? = nil) {
        var path = Path()
        path.addArc(
            center: location(x, y),
            radius: radius * scale,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        context.stroke(path, with: .color(color ?? base), lineWidth: lineWidth)
    }

    mutating func arrowhead(_ x: Double, _ y: Double, directionX: Double, directionY: Double, color: Color? = nil) {
        let length = max(hypot(directionX, directionY), 0.001)
        let ux = directionX / length
        let uy = directionY / length
        let nx = -uy
        let ny = ux
        let points = [
            (x, y),
            (x - ux * 3 + nx * 1.4, y - uy * 3 + ny * 1.4),
            (x - ux * 3 - nx * 1.4, y - uy * 3 - ny * 1.4)
        ]
        var path = Path()
        path.move(to: location(points[0].0, points[0].1))
        path.addLine(to: location(points[1].0, points[1].1))
        path.addLine(to: location(points[2].0, points[2].1))
        path.closeSubpath()
        context.fill(path, with: .color(color ?? accent))
    }

    mutating func text(_ value: String, _ x: Double, _ y: Double, size: Double, color: Color? = nil) {
        context.draw(
            Text(value)
                .font(.system(size: size * scale))
                .foregroundStyle(color ?? base),
            at: location(x, y),
            anchor: .center
        )
    }
}
