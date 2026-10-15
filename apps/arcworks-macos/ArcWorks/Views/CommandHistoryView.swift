import SwiftUI

struct CommandHistoryView: View {
    let history: [String]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if history.isEmpty {
                    Text("No command history yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(8)
        }
        .defaultScrollAnchor(.bottom)
        .frame(maxHeight: 240)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary)
        }
        .accessibilityLabel("Command History")
    }
}
