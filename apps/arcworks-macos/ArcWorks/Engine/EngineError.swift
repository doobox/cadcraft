import Foundation

enum EngineError: LocalizedError {
    case unavailable
    case invalidResponse
    case message(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "The ArcWorks drawing engine could not be started."
        case .invalidResponse:
            "The ArcWorks drawing engine returned an invalid response."
        case .message(let message):
            message
        }
    }
}

