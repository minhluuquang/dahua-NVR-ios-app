//
//  EncryptionUtility+Decrypt.swift
//  DahuaNVR
//
//  AES data decryption implementation
//

import Foundation
import CryptoSwift
import os.log

extension EncryptionUtility {
    
    /// Decrypts an AES-encrypted base64 string and returns raw decrypted data
    /// - Parameters:
    ///   - encryptedString: Base64 encoded encrypted data (IV + ciphertext)
    ///   - key: Decryption key
    ///   - profile: Encryption profile to determine mode (CBC/ECB)
    /// - Returns: Raw decrypted data
    /// - Throws: EncryptionError for decryption failures
    static func decryptWithAES(encryptedString: String, key: Data, profile: EncryptionProfile) throws -> Data {
        logger.debug("Starting AES decryption with profile: \(profile.rawValue)")
        logger.debug("Encrypted string length: \(encryptedString.count) characters, Key size: \(key.count) bytes")
        
        // Validate key size
        guard key.count == profile.keyLength else {
            throw EncryptionError.invalidKeySize(expected: profile.keyLength, actual: key.count)
        }
        
        // Decode base64 string
        guard let encryptedData = Data(base64Encoded: encryptedString) else {
            logger.error("Failed to decode base64 string")
            throw EncryptionError.invalidBase64String
        }
        
        logger.debug("Decoded encrypted data size: \(encryptedData.count) bytes")
        
        // Perform AES decryption
        let decryptedData: Data
        
        switch profile.mode {
        case "CBC":
            // For CBC mode, the server prepends the IV to the ciphertext
            // Extract IV (first 16 bytes) and ciphertext (remaining bytes)
            
            
            let iv = Array("0000000000000000".utf8)
            
            let aes = try AES(key: Array(key), blockMode: CBC(iv: Array(iv)), padding: .noPadding)
            let decryptedBytes = try aes.decrypt(Array(encryptedData))
            decryptedData = Data(decryptedBytes)
            
        case "ECB":
            let aes = try AES(key: Array(key), blockMode: ECB(), padding: .noPadding)
            let decryptedBytes = try aes.decrypt(Array(encryptedData))
            decryptedData = Data(decryptedBytes)
            
        default:
            throw EncryptionError.decryptionFailed("Unsupported decryption mode: \(profile.mode)")
        }
        
        logger.debug("Decrypted data size: \(decryptedData.count) bytes")
        
        // Remove zero padding
        let unpaddedData = removeZeroPadding(from: decryptedData)
        logger.debug("Unpadded data size: \(unpaddedData.count) bytes")
        
        // Return raw data - JSON parsing handled at higher layer
        return unpaddedData
    }
    
    /// Removes zero padding from decrypted data
    private static func removeZeroPadding(from data: Data) -> Data {
        // Find the last non-zero byte
        var lastNonZeroIndex = data.count - 1
        
        while lastNonZeroIndex >= 0 && data[lastNonZeroIndex] == 0x00 {
            lastNonZeroIndex -= 1
        }
        
        // If all bytes are zero, return empty data
        if lastNonZeroIndex < 0 {
            return Data()
        }
        
        // Return data up to and including the last non-zero byte
        return data.prefix(lastNonZeroIndex + 1)
    }
}
