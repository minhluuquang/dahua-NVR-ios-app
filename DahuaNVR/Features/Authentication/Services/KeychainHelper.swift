import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper()
    
    private init() {}
    
    private let service = "com.minhlq.DahuaNVR"
    
    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedStatus(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .duplicateItem:
                return "Item already exists in keychain"
            case .invalidItemFormat:
                return "Invalid item format"
            case .unexpectedStatus(let status):
                return "Unexpected keychain status: \(status)"
            }
        }
    }
    
    func save<T: Codable>(_ item: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(item)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            break
        case errSecDuplicateItem:
            try update(item, forKey: key)
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidItemFormat
            }
            return try JSONDecoder().decode(type, from: data)
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess, errSecItemNotFound:
            break
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func update<T: Codable>(_ item: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(item)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}