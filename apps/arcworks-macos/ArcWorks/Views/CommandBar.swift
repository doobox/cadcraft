import SwiftUI

struct CommandBar: View {
    @Bindable var document: DrawingDocument
    @FocusState private var commandIsFocused: Bool

    var body: some View {
        HStack {
            Text(document.snapshot.prompt)
                .font(.body.monospaced())
                .lineLimit(1)
            TextField("Type a command", text: $document.commandText)
                .textFieldStyle(.plain)
                .font(.body.monospaced())
                .focused($commandIsFocused)
                .onSubmit(document.submitCommand)
                .onChange(of: document.commandText) {
                    document.commandTextDidChange()
                }
                .onKeyPress(.upArrow) {
                    document.recallPreviousCommand()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    document.recallNextCommand()
                    return .handled
                }
                .onKeyPress(.tab) {
                    guard !document.commandSuggestions.isEmpty else { return .ignored }
                    document.completeCommand()
                    return .handled
                }
                .onKeyPress(.space) {
                    guard document.isAwaitingCommand else { return .ignored }
                    document.submitCommand()
                    return .handled
                }
                .accessibilityLabel("Command")
                .accessibilityHint("Type a command. Press Space or Return to run it, use Up and Down Arrow for history, or Tab to complete a suggestion.")
            Button("Run", systemImage: "return", action: document.submitCommand)
                .labelStyle(.iconOnly)
                .disabled(document.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(
                document.showsCommandHistory ? "Hide Command History" : "Show Command History",
                systemImage: document.showsCommandHistory ? "chevron.down" : "chevron.up",
                action: document.toggleCommandHistory
            )
            .labelStyle(.iconOnly)
            .help(document.showsCommandHistory ? "Hide Command History" : "Show Command History")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary)
        }
        .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
        .overlay(alignment: .bottomLeading) {
            CommandLineOverlay(
                history: document.snapshot.history,
                showsHistory: document.showsCommandHistory,
                suggestions: commandIsFocused ? Array(document.commandSuggestions.prefix(8)) : [],
                selectedSuggestionID: document.selectedCommandSuggestionID,
                runCommand: document.runCommand
            )
            .padding(.horizontal, 2)
            .offset(y: -48)
        }
        .zIndex(10)
        .onChange(of: document.commandFocusRevision) {
            commandIsFocused = true
        }
    }
}

