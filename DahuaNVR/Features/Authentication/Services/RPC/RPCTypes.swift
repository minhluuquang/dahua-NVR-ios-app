import Foundation

struct AnyJSON: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyJSON].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyJSON].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map(AnyJSON.init))
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues(AnyJSON.init))
        } else {
            try container.encodeNil()
        }
    }
    
    var dictionary: [String: Any]? {
        return value as? [String: Any]
    }
    
    var array: [Any]? {
        return value as? [Any]
    }
    
    var string: String? {
        return value as? String
    }
    
    var int: Int? {
        return value as? Int
    }
    
    var double: Double? {
        return value as? Double
    }
    
    var bool: Bool? {
        return value as? Bool
    }
}

struct EmptyResponse: Codable {
    // Empty response for operations that don't return data
}

struct SuccessResponse: Codable {
    let result: Bool
    let error: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let resultBool = try? container.decode(Bool.self, forKey: .result) {
            self.result = resultBool
        } else if let resultString = try? container.decode(String.self, forKey: .result),
                  resultString.lowercased() == "ok" || resultString.lowercased() == "true" {
            self.result = true
        } else {
            self.result = false
        }
        
        self.error = try container.decodeIfPresent(String.self, forKey: .error)
    }
    
    private enum CodingKeys: String, CodingKey {
        case result, error
    }
}