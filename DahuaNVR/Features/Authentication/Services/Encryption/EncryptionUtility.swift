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
        return packet
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
        var keyData = Data(count: length)
        let result = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw EncryptionError.encryptionFailed("Failed to generate random key")
        }
        
        logger.debug("Generated symmetric key of \(length) bytes")
        return keyData
    }
}