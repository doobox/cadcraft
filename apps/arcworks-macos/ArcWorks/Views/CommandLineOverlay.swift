import SwiftUI

struct CommandLineOverlay: View {
    let history: [String]
    let showsHistory: Bool
    let suggestions: [CommandSuggestion]
    let selectedSuggestionID: String?
    let runCommand: (CommandSuggestion) -> Void

    var body: some View {
        VStack(spacing: 6) {
            if !suggestions.isEmpty {
                CommandSuggestionsView(
                    suggestions: suggestions,
                    selectedSuggestionID: selectedSuggestionID,
                    runCommand: runCommand
                )
            }
            if showsHistory {
                CommandHistoryView(history: history)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
