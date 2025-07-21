//
//  EncryptionUtility+AES.swift
//  DahuaNVR
//
//  AES data encryption implementation
//

import Foundation
import CryptoSwift
import os.log

extension EncryptionUtility {
    
    static func encryptWithAES(data: Data, key: Data, profile: EncryptionProfile) throws -> String {
        logger.debug("Starting AES encryption with profile: \(profile.rawValue)")
        logger.debug("Data size: \(data.count) bytes, Key size: \(key.count) bytes")
        
        guard key.count == profile.keyLength else {
            throw EncryptionError.invalidKeySize(expected: profile.keyLength, actual: key.count)
        }
        
        let paddedData = applyZeroPadding(to: data)
        logger.debug("Padded data size: \(paddedData.count) bytes")
        
        let encrypted: Data
        
        switch profile.mode {
        case "CBC":
            let iv = Data(repeating: 0x00, count: 16)
            let aes = try AES(key: Array(key), blockMode: CBC(iv: Array(iv)), padding: .noPadding)
            let encryptedBytes = try aes.encrypt(Array(paddedData))
            encrypted = Data(encryptedBytes)
            
        case "ECB":
            let aes = try AES(key: Array(key), blockMode: ECB(), padding: .noPadding)
            let encryptedBytes = try aes.encrypt(Array(paddedData))
            encrypted = Data(encryptedBytes)
            
        default:
            throw EncryptionError.encryptionFailed("Unsupported encryption mode: \(profile.mode)")
        }
        
        let base64String = encrypted.base64EncodedString()
        logger.debug("AES encryption completed. Output size: \(base64String.count) characters")
        
        return base64String
    }
    
    private static func applyZeroPadding(to data: Data) -> Data {
        let blockSize = 16
        let padding = (blockSize - (data.count % blockSize)) % blockSize
        
        if padding == 0 {
            return data
        }
        
        var paddedData = data
        paddedData.append(Data(repeating: 0x00, count: padding))
        return paddedData
    }
}