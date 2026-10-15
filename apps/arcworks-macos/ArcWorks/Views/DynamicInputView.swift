import SwiftUI

struct DynamicInputView: View {
    let prompt: String
    let feedback: CursorFeedback
    let entry: String

    var body: some View {
        if !entry.isEmpty || feedback.distance != nil || feedback.inference != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text(prompt)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let inference = feedback.inference {
                    Label(inference, systemImage: "scope")
                        .foregroundStyle(.cyan)
                        .lineLimit(2)
                }

                if !entry.isEmpty {
                    Text(entry)
                        .foregroundStyle(.primary)
                } else if let distance = feedback.distance, let angle = feedback.angleDegrees {
                    HStack(spacing: 10) {
                        Label {
                            Text(distance, format: .number.precision(.fractionLength(3)))
                        } icon: {
                            Image(systemName: "ruler")
                        }
                        Label {
                            Text(angle, format: .number.precision(.fractionLength(1))) + Text("°")
                        } icon: {
                            Image(systemName: "angle")
                        }
                    }
                }
            }
            .font(.callout.monospaced())
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: .rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator, lineWidth: 1)
            }
            .shadow(radius: 4, y: 2)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
        }
    }
}
