//
//  EncryptionUtility.swift
//  DahuaNVR
//
//  Main encryption orchestrator for hybrid RSA/AES encryption
//

import Foundation
import BigInt
import os.log

public final class EncryptionUtility {
    
    static let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "EncryptionUtility")
    
    private static let clientProfiles: [EncryptionProfile] = [.RPAC, .AES]
    
    public static func encrypt(payload: Encodable, serverCiphers: [String]) throws -> EncryptedPacket {
        let (packet, _) = try encryptWithKey(payload: payload, serverCiphers: serverCiphers)
        return packet
    }
    
    public static func encryptWithKey(payload: Encodable, serverCiphers: [String]) throws -> (packet: EncryptedPacket, key: Data) {
        logger.debug("Starting encryption process")
        logger.debug("Server ciphers: \(serverCiphers.joined(separator: ", "))")
        
        let config = CryptoConfiguration.shared
        
        guard let modulus = config.parsedModulus,
              let exponent = config.parsedExponent else {
            throw EncryptionError.invalidPublicKey("RSA public key not configured")
        }
        
        let profile = try selectProfile(serverCiphers: serverCiphers)
        logger.debug("Selected encryption profile: \(profile.rawValue)")
        
        let symmetricKey = try generateSymmetricKey(length: profile.keyLength)
        
        let rsaEncrypted = try encryptWithRSA(data: symmetricKey, modulus: modulus, exponent: exponent)
        
        let payloadData = try JSONEncoder().encode(payload)
        
        let aesEncrypted = try encryptWithAES(data: payloadData, key: symmetricKey, profile: profile)
        
        let packet = EncryptedPacket(
            cipher: profile.cipherName,
            salt: rsaEncrypted,
            content: aesEncrypted
        )
        
        logger.debug("Encryption completed successfully")
        return (packet: packet, key: symmetricKey)
    }
    
    static func selectProfile(serverCiphers: [String]) throws -> EncryptionProfile {
        for profile in clientProfiles {
            if serverCiphers.contains(profile.cipherName) {
                return profile
            }
        }
        
        let availableProfiles = clientProfiles.map { $0.cipherName }
        throw EncryptionError.noCipherMatch(available: availableProfiles, serverCiphers: serverCiphers)
    }
    
    static func generateSymmetricKey(length: Int) throws -> Data {
        let randomNumericString = generateRandomNumericString(length: length)
        
        guard let keyData = randomNumericString.data(using: .utf8) else {
            throw EncryptionError.encryptionFailed("Failed to convert random numeric string to Data")
        }
        
        logger.debug("Generated symmetric key of \(length) bytes")
        return keyData
    }
    
    private static func generateRandomNumericString(length: Int) -> String {
        var resultString = ""
        
        // Base case: Handle requests for lengths of 16 or less
        if length <= 16 {
            // Generate a random float and convert it to string representation
            let randomFloatString = String(Double.random(in: 0..<1))
            
            // Take the last 'length' characters from the string
            let numericSlice = String(randomFloatString.suffix(length))
            
            // If the first character is "0", recursively call to try again
            if numericSlice.first == "0" {
                return generateRandomNumericString(length: length)
            } else {
                resultString = numericSlice
            }
        } else {
            // Recursive step: Handle requests for lengths greater than 16
            let chunksOf16 = length / 16
            for _ in 0..<chunksOf16 {
                resultString += generateRandomNumericString(length: 16)
            }
            
            let remainder = length % 16
            if remainder > 0 {
                resultString += generateRandomNumericString(length: remainder)
            }
        }
        
        return resultString
    }
}
