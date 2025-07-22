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
    
    /// Decrypts an AES-encrypted base64 string and returns parsed JSON data
    /// - Parameters:
    ///   - encryptedString: Base64 encoded encrypted data
    ///   - key: Decryption key
    ///   - profile: Encryption profile to determine mode (CBC/ECB)
    /// - Returns: Parsed JSON dictionary or nil if parsing fails
    /// - Throws: EncryptionError for decryption failures
    static func decryptWithAES(encryptedString: String, key: Data, profile: EncryptionProfile) throws -> [String: Any]? {
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
            // Use static IV of 16 zero bytes
            let iv = Data(repeating: 0x00, count: 16)
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
        
        // Parse JSON with fallback encoding
        return try parseJSONWithFallback(from: unpaddedData)
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
    
    /// Parses JSON data with UTF-8 primary attempt and Latin-1 fallback
    private static func parseJSONWithFallback(from data: Data) throws -> [String: Any]? {
        // Primary attempt: UTF-8 decoding
        if let utf8String = String(data: data, encoding: .utf8) {
            logger.debug("Successfully decoded data as UTF-8")
            
            do {
                if let jsonData = utf8String.data(using: .utf8),
                   let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    logger.debug("Successfully parsed JSON from UTF-8 string")
                    return jsonObject
                }
            } catch {
                logger.warning("Failed to parse JSON from UTF-8 string: \(error.localizedDescription)")
            }
        } else {
            logger.warning("Failed to decode data as UTF-8, trying Latin-1 fallback")
        }
        
        // Fallback attempt: Latin-1 (ISO-8859-1) decoding
        if let latin1String = String(data: data, encoding: .isoLatin1) {
            logger.debug("Successfully decoded data as Latin-1")
            
            do {
                // Convert Latin-1 string back to data for JSON parsing
                if let jsonData = latin1String.data(using: .utf8),
                   let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    logger.debug("Successfully parsed JSON from Latin-1 string")
                    return jsonObject
                }
            } catch {
                logger.warning("Failed to parse JSON from Latin-1 string: \(error.localizedDescription)")
            }
        }
        
        // Both attempts failed
        logger.error("Failed to parse JSON data - characters are unrecognizable or data is corrupt")
        return nil
    }
}