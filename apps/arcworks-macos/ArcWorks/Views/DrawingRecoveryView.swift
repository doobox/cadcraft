import SwiftUI

struct DrawingRecoveryView: View {
    @Bindable var document: DrawingDocument
    @State private var itemToDiscard: DrawingRecoveryItem?
    @State private var showsDiscardConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Drawing Recovery", systemImage: "arrow.counterclockwise.circle")
                .font(.title2)
            Text("ArcWorks found recovery copies left by an earlier session that did not close normally.")
                .foregroundStyle(.secondary)

            List(document.recoveryItems) { item in
                DrawingRecoveryRow(
                    item: item,
                    open: { document.recoverDrawing(item) },
                    discard: { requestDiscard(item) }
                )
            }
            .frame(minHeight: 180)

            HStack {
                Text("Recovered drawings open as unsaved copies so the original file is not overwritten.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Later", action: document.dismissDrawingRecovery)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 320)
        .confirmationDialog(
            "Discard Recovery Copy?",
            isPresented: $showsDiscardConfirmation,
            presenting: itemToDiscard
        ) { item in
            Button("Discard “\(item.drawing)”", role: .destructive) {
                document.discardRecovery(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("This permanently removes the recovery copy for “\(item.drawing)”.")
        }
    }

    private func requestDiscard(_ item: DrawingRecoveryItem) {
        itemToDiscard = item
        showsDiscardConfirmation = true
    }
}
