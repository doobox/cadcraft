import Foundation

struct DrawingRecoveryItem: Decodable, Identifiable, Sendable {
    let path: String
    let drawing: String
    let modified: UInt64
    let bytes: UInt64

    var id: String { path }

    var modifiedDate: Date {
        Date(timeIntervalSince1970: TimeInterval(modified))
    }
}
