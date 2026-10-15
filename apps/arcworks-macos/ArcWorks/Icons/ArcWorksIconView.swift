import SwiftUI

struct ArcWorksIconView: View {
    let icon: ArcWorksIcon
    var monochrome: Color?

    init(_ icon: ArcWorksIcon, monochrome: Color? = nil) {
        self.icon = icon
        self.monochrome = monochrome
    }

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Canvas { context, size in
            let base = monochrome ?? Color(nsColor: .labelColor)
            let accent = monochrome ?? Color(nsColor: .systemBlue)
            let point = monochrome ?? Color(nsColor: .systemOrange)
            let opacity = isEnabled ? 1.0 : 0.4

            context.opacity = opacity
            ArcWorksIconRenderer.draw(
                icon,
                in: &context,
                size: size,
                base: base,
                accent: accent,
                point: point
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
