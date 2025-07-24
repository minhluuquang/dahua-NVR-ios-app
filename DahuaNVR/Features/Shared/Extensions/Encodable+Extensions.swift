import Foundation

extension Encodable {
    func toDictionary() -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { 
            print("❌ [Encodable+Extensions] Failed to encode object to JSON data")
            return nil 
        }
        
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else {
            print("❌ [Encodable+Extensions] Failed to serialize JSON data to object")
            return nil
        }
        
        guard let dictionary = jsonObject as? [String: Any] else {
            print("❌ [Encodable+Extensions] JSON object is not a dictionary")
            return nil
        }
        
        return dictionary
    }
}