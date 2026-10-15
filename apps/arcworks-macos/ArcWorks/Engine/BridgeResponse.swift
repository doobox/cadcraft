import Foundation

struct BridgeResponse: Decodable {
    let ok: Bool
    let error: String?
    let snapshot: DrawingSnapshot?
    let cursor: CursorFeedback?
    let clipboardText: String?
    let commands: [CommandSuggestion]?
    let recoveries: [DrawingRecoveryItem]?
}

