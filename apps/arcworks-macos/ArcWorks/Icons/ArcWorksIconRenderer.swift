import SwiftUI

enum ArcWorksIconRenderer {
    static func draw(
        _ icon: ArcWorksIcon,
        in context: inout GraphicsContext,
        size: CGSize,
        base: Color,
        accent: Color,
        point: Color
    ) {
        var pen = ArcWorksIconPainter(context: context, size: size, base: base, accent: accent, pointColor: point)

        switch icon {
        case .line:
            pen.line(4, 20, 20, 4, color: accent)
            pen.filledCircle(4, 20, radius: 1.5)
            pen.filledCircle(20, 4, radius: 1.5)
        case .polyline:
            pen.polyline([(3, 19), (8, 8), (14, 15)], color: accent)
            pen.arc(17, 11, radius: 5, start: 40, end: 180, color: accent)
            for p in [(3.0, 19.0), (8, 8), (14, 15)] { pen.filledCircle(p.0, p.1, radius: 1.5) }
        case .circle:
            pen.circle(12, 12, radius: 8, color: accent)
            pen.line(12, 12, 18, 6.5)
            pen.filledCircle(12, 12, radius: 1.5)
        case .arc:
            pen.arc(12, 16, radius: 9, start: 195, end: 345, color: accent)
            for p in [(3.2, 14.5), (12, 7), (20.8, 14.5)] { pen.filledCircle(p.0, p.1, radius: 1.5) }
        case .rectangle:
            pen.rectangle(3, 6, width: 18, height: 12, color: accent)
            pen.filledCircle(3, 18, radius: 1.5)
            pen.filledCircle(21, 6, radius: 1.5)
        case .polygon:
            let points = (0..<6).map { index in
                let angle = Double(index) * .pi / 3
                return (12 + 8.5 * cos(angle), 12 + 8.5 * sin(angle))
            }
            pen.polyline(points, closed: true, color: accent)
            pen.filledCircle(12, 12, radius: 1.4)
        case .ellipse:
            pen.ellipse(12, 12, radiusX: 9, radiusY: 5, color: accent)
            pen.filledCircle(3, 12, radius: 1.5)
            pen.filledCircle(21, 12, radius: 1.5)
        case .spline:
            let points = (0...20).map { index in
                let fraction = Double(index) / 20
                return (3 + 18 * fraction, 12 - 6 * sin(fraction * .pi * 2))
            }
            pen.polyline(points, color: accent)
            for p in [(3.0, 12.0), (7.5, 6), (16.5, 18), (21, 12)] { pen.filledCircle(p.0, p.1, radius: 1.5) }
        case .constructionLine:
            pen.line(1, 22, 23, 2, color: accent)
            pen.filledCircle(12, 12, radius: 1.5)
        case .ray:
            pen.line(5, 19, 23, 3, color: accent)
            pen.filledCircle(5, 19, radius: 1.5)
        case .point:
            pen.filledCircle(12, 12, radius: 1.5)
            pen.line(12, 5, 12, 9)
            pen.line(12, 15, 12, 19)
            pen.line(5, 12, 9, 12)
            pen.line(15, 12, 19, 12)
        case .donut:
            pen.circle(12, 12, radius: 8, color: accent)
            pen.circle(12, 12, radius: 4.5, color: accent)
            pen.filledCircle(12, 12, radius: 1, color: base)
        case .revisionCloud:
            for index in 0..<6 {
                let angle = Double(index) * 60
                let radians = angle * .pi / 180
                pen.arc(
                    12 + 6 * cos(radians),
                    12 + 6 * sin(radians),
                    radius: 3.2,
                    start: -angle - 70,
                    end: -angle + 110,
                    color: accent
                )
            }
        case .region:
            pen.polyline([(4, 18), (6, 6), (16, 4), (20, 14), (12, 20)], closed: true, color: accent)
            pen.filledCircle(12, 12, radius: 3, color: accent.opacity(0.5))
        case .wipeout:
            pen.rectangle(3, 3, width: 13, height: 13)
            pen.filledRectangle(8, 8, width: 13, height: 13, color: Color(nsColor: .controlBackgroundColor))
            pen.rectangle(8, 8, width: 13, height: 13, color: accent)
        case .hatch:
            pen.rectangle(3, 3, width: 18, height: 18)
            for index in 0..<5 {
                let offset = Double(index) * 4.5
                pen.line(min(3 + offset, 21), 21, 21, max(21 - (18 - offset), 3), color: accent)
                pen.line(3, 21 - offset, min(3 + offset, 21), 21 - offset - min(offset, 18) + offset, color: accent)
            }
        case .gradient:
            pen.gradientRectangle(3, 3, width: 18, height: 18)
            pen.rectangle(3, 3, width: 18, height: 18)
        case .boundary:
            pen.rectangle(4, 4, width: 16, height: 16)
            pen.circle(12, 12, radius: 6)
            pen.rectangle(4, 4, width: 16, height: 16, color: accent)
            pen.filledCircle(6, 6, radius: 1.4)
        case .block, .insert, .blockEdit, .attribute:
            pen.polyline([(9, 4), (17, 8), (9, 12), (1, 8)], closed: true)
            pen.polyline([(1, 8), (1, 15), (9, 19), (17, 15), (17, 8)])
            switch icon {
            case .block:
                pen.text("✳", 19, 5, size: 9, color: point)
            case .insert:
                pen.line(14, 20, 22, 20, color: accent)
                pen.arrowhead(13, 20, directionX: -1, directionY: 0, color: accent)
            case .blockEdit:
                pen.line(14, 22, 22, 14, color: accent)
            case .attribute:
                pen.text("A", 19, 19, size: 9, color: accent)
            default:
                break
            }
        case .erase:
            pen.polyline([(4, 16), (13, 7), (19, 13), (12, 20), (8, 20)], closed: true)
            pen.line(9, 11, 15, 17, color: accent)
            pen.line(8, 20, 20, 20)
        case .move:
            pen.line(12, 3, 12, 21, color: accent)
            pen.line(3, 12, 21, 12, color: accent)
            pen.arrowhead(12, 2, directionX: 0, directionY: -1, color: accent)
            pen.arrowhead(12, 22, directionX: 0, directionY: 1, color: accent)
            pen.arrowhead(2, 12, directionX: -1, directionY: 0, color: accent)
            pen.arrowhead(22, 12, directionX: 1, directionY: 0, color: accent)
        case .copy:
            pen.rectangle(3, 3, width: 11, height: 13)
            pen.rectangle(10, 8, width: 11, height: 13, color: accent)
        case .rotate:
            pen.arc(12, 12, radius: 8, start: 100, end: 380, color: accent)
            pen.arrowhead(10.6, 4.1, directionX: -1, directionY: 0.1, color: accent)
            pen.filledCircle(12, 12, radius: 1.5)
        case .scale:
            pen.rectangle(3, 11, width: 10, height: 10)
            pen.rectangle(3, 3, width: 18, height: 18, color: accent)
            pen.line(9, 15, 18, 6, color: accent)
            pen.arrowhead(19, 5, directionX: 1, directionY: -1, color: accent)
        case .mirror:
            pen.polyline([(3, 18), (9, 6), (9, 18)], closed: true)
            pen.polyline([(21, 18), (15, 6), (15, 18)], closed: true, color: accent)
            for y in stride(from: 3.0, through: 19.0, by: 4.0) { pen.line(12, y, 12, y + 2) }
        case .stretch:
            pen.polyline([(3, 18), (3, 8), (10, 8)])
            pen.polyline([(10, 8), (20, 8), (20, 18), (3, 18)], color: accent)
            for x in [12.0, 15, 18, 21] { pen.line(x, 5, x + 1.5, 5) }
        case .offset:
            pen.arc(14, 18, radius: 6, start: 90, end: 180)
            pen.line(14, 12, 21, 12)
            pen.line(8, 18, 8, 22)
            pen.arc(14, 18, radius: 10, start: 90, end: 180, color: accent)
            pen.line(14, 8, 21, 8, color: accent)
            pen.line(4, 18, 4, 22, color: accent)
        case .trim:
            pen.line(8, 2, 8, 22)
            pen.line(16, 2, 16, 22)
            pen.line(2, 12, 8, 12)
            pen.line(16, 12, 22, 12)
            for x in [9.5, 12, 14.5] { pen.line(x, 12, x + 1, 12, color: accent) }
            pen.polyline([(10, 17), (12, 15), (14, 17)], color: accent)
        case .extend:
            pen.line(20, 2, 20, 22)
            pen.line(3, 12, 11, 12)
            pen.line(11, 12, 19, 12, color: accent)
            pen.arrowhead(19.5, 12, directionX: 1, directionY: 0, color: accent)
        case .fillet:
            pen.line(4, 20, 4, 12)
            pen.line(12, 4, 20, 4)
            pen.arc(12, 12, radius: 8, start: 180, end: 270, color: accent)
        case .chamfer:
            pen.line(4, 20, 4, 10)
            pen.line(10, 4, 20, 4)
            pen.line(4, 10, 10, 4, color: accent)
        case .breakLine:
            pen.line(3, 12, 9, 12)
            pen.line(15, 12, 21, 12)
            pen.filledCircle(9, 12, radius: 1.5)
            pen.filledCircle(15, 12, radius: 1.5)
        case .join:
            pen.line(3, 16, 11, 8)
            pen.line(11, 8, 21, 16, color: accent)
            pen.filledCircle(11, 8, radius: 1.5)
        case .explode:
            for line in [(4.0, 9.0, 9.0, 4.0), (15, 4, 20, 9), (20, 15, 15, 20), (9, 20, 4, 15)] {
                pen.line(line.0, line.1, line.2, line.3, color: accent)
            }
            pen.filledCircle(12, 12, radius: 2)
        case .arrayRectangular:
            for column in 0..<3 {
                for row in 0..<3 {
                    pen.rectangle(
                        3 + Double(column) * 7,
                        3 + Double(row) * 7,
                        width: 4,
                        height: 4,
                        color: column + row == 0 ? base : accent
                    )
                }
            }
        case .arrayPolar:
            pen.filledCircle(12, 12, radius: 1.5)
            for index in 0..<6 {
                let angle = Double(index) * .pi / 3
                pen.circle(
                    12 + 7.5 * cos(angle),
                    12 + 7.5 * sin(angle),
                    radius: 2,
                    color: index == 0 ? base : accent
                )
            }
        case .lengthen:
            pen.line(3, 12, 13, 12)
            pen.line(13, 12, 20, 12, color: accent)
            pen.arrowhead(21, 12, directionX: 1, directionY: 0, color: accent)
        case .text:
            pen.text("A", 12, 12.5, size: 19)
        case .multilineText:
            pen.text("A", 9, 11, size: 15)
            for y in [15.0, 18, 21] { pen.line(14, y, y == 21 ? 19 : 21, y, color: accent) }
        case .table:
            pen.rectangle(3, 4, width: 18, height: 16)
            pen.filledRectangle(3, 4, width: 18, height: 4, color: accent.opacity(0.6))
            for y in [8.0, 12, 16] { pen.line(3, y, 21, y) }
            pen.line(9, 8, 9, 20)
            pen.line(15, 8, 15, 20)
        case .dimension, .linearDimension, .alignedDimension, .distance, .baselineDimension, .continueDimension, .quickDimension:
            pen.line(4, 18, 4, 5)
            pen.line(20, 18, 20, 5)
            pen.line(4, 8, 20, 8, color: accent)
            pen.arrowhead(4, 8, directionX: -1, directionY: 0, color: accent)
            pen.arrowhead(20, 8, directionX: 1, directionY: 0, color: accent)
            switch icon {
            case .baselineDimension:
                pen.line(4, 4, 13, 4, color: accent)
            case .continueDimension:
                pen.line(12, 18, 12, 5)
            case .quickDimension:
                pen.text("Q", 12, 15, size: 7)
            case .alignedDimension:
                break
            default:
                pen.text("1.5", 12, 15, size: 6)
            }
        case .radiusDimension:
            pen.arc(12, 14, radius: 8, start: 180, end: 360)
            pen.line(12, 14, 17.6, 8.4, color: accent)
            pen.arrowhead(17.6, 8.4, directionX: 1, directionY: -1, color: accent)
            pen.filledCircle(12, 14, radius: 1.4)
        case .diameterDimension:
            pen.circle(12, 12, radius: 8)
            pen.line(6.4, 17.6, 17.6, 6.4, color: accent)
            pen.arrowhead(6.4, 17.6, directionX: -1, directionY: 1, color: accent)
            pen.arrowhead(17.6, 6.4, directionX: 1, directionY: -1, color: accent)
        case .angularDimension:
            pen.line(4, 20, 20, 20)
            pen.line(4, 20, 16, 6)
            pen.arc(4, 20, radius: 11, start: 270, end: 319, color: accent)
        case .arcDimension:
            pen.arc(12, 18, radius: 8, start: 200, end: 340)
            pen.arc(12, 18, radius: 12, start: 205, end: 335, color: accent)
        case .ordinateDimension:
            pen.line(4, 20, 4, 4)
            pen.line(4, 20, 20, 20)
            pen.line(10, 20, 10, 8, color: accent)
            pen.line(16, 20, 16, 11, color: accent)
        case .centerMark:
            pen.circle(12, 12, radius: 7)
            pen.line(12, 2, 12, 22, color: accent)
            pen.line(2, 12, 22, 12, color: accent)
        case .centerLine:
            for x in stride(from: 2.0, through: 20.0, by: 6.0) { pen.line(x, 12, min(x + 4, 22), 12, color: accent) }
        case .settings, .properties:
            for y in [6.0, 12, 18] {
                pen.line(3, y, 21, y)
                let x = y == 6 ? 8.0 : (y == 12 ? 16 : 11)
                pen.circle(x, y, radius: 2.2, color: accent)
            }
        case .multileader, .addLeader, .removeLeader, .alignLeaders:
            pen.line(3, 20, 10, 9, color: accent)
            pen.line(10, 9, 14, 9, color: accent)
            pen.arrowhead(3, 20, directionX: -0.55, directionY: 1, color: accent)
            pen.line(15, 6, 22, 6)
            pen.line(15, 10, 21, 10)
            if icon == .addLeader {
                pen.text("+", 19, 18, size: 9, color: point)
            } else if icon == .removeLeader {
                pen.text("−", 19, 18, size: 9, color: point)
            }
        case .layers:
            for (index, y) in [5.0, 10, 15].enumerated() {
                pen.polyline([(3, y + 2), (12, y - 2), (21, y + 2), (12, y + 6)], closed: true, color: index == 0 ? accent : base)
            }
        case .linetype:
            pen.line(3, 6, 21, 6)
            for x in stride(from: 3.0, through: 19.0, by: 6.0) { pen.line(x, 12, x + 3, 12, color: accent) }
            for x in stride(from: 3.0, through: 19.0, by: 4.0) { pen.filledCircle(x, 18, radius: 0.8, color: base) }
        case .matchProperties:
            pen.rectangle(4, 3, width: 14, height: 6)
            pen.polyline([(18, 6), (20, 6), (20, 11), (11, 11), (11, 14)])
            pen.filledRectangle(9.5, 14, width: 3, height: 8, color: accent)
        case .area:
            pen.polyline([(4, 18), (7, 6), (17, 4), (21, 15), (12, 21)], closed: true, color: accent)
            pen.text("A", 12, 12, size: 7)
        case .pointID, .objectSnap:
            pen.rectangle(7, 7, width: 10, height: 10)
            pen.line(12, 2, 12, 7)
            pen.line(12, 17, 12, 22)
            pen.line(2, 12, 7, 12)
            pen.line(17, 12, 22, 12)
        case .list:
            for y in [6.0, 12, 18] {
                pen.filledCircle(4, y, radius: 1, color: accent)
                pen.line(8, y, 21, y)
            }
        case .ortho:
            pen.polyline([(4, 3), (4, 20), (21, 20)])
        case .polar:
            pen.line(4, 20, 21, 20)
            pen.line(4, 20, 18, 6)
            pen.arc(4, 20, radius: 9, start: 270, end: 315, color: accent)
            pen.filledCircle(4, 20, radius: 1.2, color: accent)
        case .grid:
            for value in stride(from: 4.0, through: 20.0, by: 5.33) {
                pen.line(value, 3, value, 21)
                pen.line(3, value, 21, value)
            }
        case .snap:
            for x in stride(from: 4.0, through: 20.0, by: 5.33) {
                for y in stride(from: 4.0, through: 20.0, by: 5.33) { pen.filledCircle(x, y, radius: 1, color: base) }
            }
        case .dynamicInput:
            pen.rectangle(3, 6, width: 18, height: 12)
            pen.text("12", 10, 12, size: 7, color: accent)
            pen.line(16, 9, 16, 15, color: accent)
        case .objectSnapTracking:
            pen.rectangle(9, 9, width: 6, height: 6)
            for x in [2.0, 5, 17, 20] { pen.filledCircle(x, 12, radius: 0.8, color: accent) }
            for y in [2.0, 5, 17, 20] { pen.filledCircle(12, y, radius: 0.8, color: accent) }
        }

        context = pen.context
    }
}
