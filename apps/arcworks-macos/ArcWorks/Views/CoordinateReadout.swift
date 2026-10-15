import SwiftUI

struct CoordinateReadout: View {
    let point: WorldPoint

    var body: some View {
        Text("\(point.x, format: .number.precision(.fractionLength(4))), \(point.y, format: .number.precision(.fractionLength(4))), 0.0000")
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityLabel("Cursor coordinates")
            .accessibilityValue("X \(point.x), Y \(point.y), Z zero")
    }
}
