import Foundation
import Testing

/// Decodes API models (no public initialisers) from compact JSON.
func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(json.utf8))
}

func decode<T: Decodable>(_ json: String) throws -> T { try decode(T.self, json) }

/// A fresh, empty UserDefaults suite that is wiped when the returned name is reused.
func isolatedDefaults(_ name: String) -> UserDefaults {
    UserDefaults().removePersistentDomain(forName: name)
    return UserDefaults(suiteName: name)!
}
