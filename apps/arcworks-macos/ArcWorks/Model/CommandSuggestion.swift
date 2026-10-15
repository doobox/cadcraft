import Foundation

struct CommandSuggestion: Codable, Identifiable, Sendable {
    let id: String
    let label: String
    let aliases: [String]
    let shortcut: String?
}
