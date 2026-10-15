import Foundation

enum PropertyJSON {
    static func string(from json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    static func number(from json: String) -> Double? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Double.self, from: data)
    }

    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
