import SwiftUI

struct CommandSuggestionsView: View {
    let suggestions: [CommandSuggestion]
    let selectedSuggestionID: String?
    let runCommand: (CommandSuggestion) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    runCommand(suggestion)
                } label: {
                    HStack {
                        Text(suggestion.id.uppercased())
                            .font(.body.monospaced())
                        Text(suggestion.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let shortcut = suggestion.shortcut {
                            Text(shortcut)
                                .foregroundStyle(.tertiary)
                        } else if let alias = suggestion.aliases.first {
                            Text(alias.uppercased())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        suggestion.id == selectedSuggestionID
                            ? Color.accentColor.opacity(0.18)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(suggestion.label), command \(suggestion.id)")
                .accessibilityAddTraits(suggestion.id == selectedSuggestionID ? .isSelected : [])

                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary)
        }
    }
}
