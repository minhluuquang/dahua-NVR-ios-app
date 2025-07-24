import Foundation

/// A property wrapper that filters out null values from decoded arrays
/// This makes the app more resilient to unexpected server responses
@propertyWrapper
struct FailableDecodableArray<Element: Codable>: Codable {
    var wrappedValue: [Element] = []

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                wrappedValue.append(element)
            } else {
                // This is where null values would be - we skip them gracefully
                _ = try? container.decode(FailableNil.self)
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in wrappedValue {
            try container.encode(element)
        }
    }
    
    /// Helper struct to decode and discard null values
    private struct FailableNil: Codable {}
}

/// Extension to provide default initialization
extension FailableDecodableArray {
    init(wrappedValue: [Element]) {
        self.wrappedValue = wrappedValue
    }
}