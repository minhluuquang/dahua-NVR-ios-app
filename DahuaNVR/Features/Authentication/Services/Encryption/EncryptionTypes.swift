//
//  EncryptionTypes.swift
//  DahuaNVR
//
//  Core types for the hybrid encryption system
//

import Foundation

public enum EncryptionProfile: String, CaseIterable {
    case RPAC = "RPAC"
    case AES = "AES"
    
    var keyLength: Int {
        switch self {
        case .RPAC:
            return 32
        case .AES:
            return 16
        }
    }
    
    var mode: String {
        switch self {
        case .RPAC:
            return "CBC"
        case .AES:
            return "ECB"
        }
    }
    
    var cipherName: String {
        switch self {
        case .RPAC:
            return "RPAC-256"
        case .AES:
            return "AES-128"
        }
    }
}

public struct EncryptedPacket: Codable {
    public let cipher: String
    public let salt: String
    public let content: String
    
    public init(cipher: String, salt: String, content: String) {
        self.cipher = cipher
        self.salt = salt
        self.content = content
    }
}

public enum EncryptionError: Error, LocalizedError, Equatable {
    case invalidPublicKey(String)
    case noCipherMatch(available: [String], serverCiphers: [String])
    case encryptionFailed(String)
    case invalidKeySize(expected: Int, actual: Int)
    case dataConversionFailed
    case decryptionFailed(String)
    case invalidBase64String
    case invalidJSONData(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPublicKey(let detail):
            return "Invalid RSA public key format: \(detail)"
        case .noCipherMatch(let available, let serverCiphers):
            return "No matching cipher found. Client: \(available), Server: \(serverCiphers)"
        case .encryptionFailed(let detail):
            return "Encryption failed: \(detail)"
        case .invalidKeySize(let expected, let actual):
            return "Invalid key size. Expected: \(expected) bytes, Got: \(actual) bytes"
        case .dataConversionFailed:
            return "Failed to convert data during encryption process"
        case .decryptionFailed(let detail):
            return "Decryption failed: \(detail)"
        case .invalidBase64String:
            return "Invalid base64 encoded string"
        case .invalidJSONData(let detail):
            return "Failed to parse JSON data: \(detail)"
        }
    }
}