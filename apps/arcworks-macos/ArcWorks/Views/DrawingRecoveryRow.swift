import SwiftUI

struct DrawingRecoveryRow: View {
    let item: DrawingRecoveryItem
    let open: () -> Void
    let discard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.badge.clock")
                .imageScale(.large)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.drawing)
                    .font(.headline)
                Text(item.modifiedDate, format: .dateTime.year().month().day().hour().minute())
                    .foregroundStyle(.secondary)
                Text(Int64(item.bytes), format: .byteCount(style: .file))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Open", action: open)
                .buttonStyle(.borderedProminent)
            Button("Discard", role: .destructive, action: discard)
        }
        .padding(.vertical, 4)
    }
}
