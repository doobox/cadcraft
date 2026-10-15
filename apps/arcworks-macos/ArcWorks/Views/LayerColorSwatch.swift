import SwiftUI

struct LayerColorSwatch: View {
    let hex: String

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay {
                Circle().stroke(.separator, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var color: Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return .primary }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
