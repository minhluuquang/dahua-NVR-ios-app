//
//  EncryptionUtility+RSA.swift
//  DahuaNVR
//
//  RSA key encapsulation implementation using CryptoSwift with PKCS#1 v1.5 padding
//

import Foundation
import CryptoSwift
import BigInt
import os.log

extension EncryptionUtility {
    
    static func encryptWithRSA(data: Data, modulus: BigInt, exponent: BigInt) throws -> String {
        logger.debug("Starting RSA encryption for \(data.count) bytes using PKCS#1 v1.5")
        
        // Convert BigInt modulus and exponent to byte arrays
        let modulusBytes = modulusToBytes(modulus)
        let exponentBytes = exponentToBytes(exponent)
        
        logger.debug("RSA Key parameters - Modulus: \(modulusBytes.count) bytes, Exponent: \(exponentBytes.count) bytes")
        
        // Create RSA instance with public key parameters
        // Note: We only have n and e (public key), not d (private key)
        let rsa = RSA(n: modulusBytes, e: exponentBytes, d: nil)
        
        // Encrypt the data using PKCS#1 v1.5 padding (CryptoSwift default)
        let encryptedBytes = try rsa.encrypt(Array(data))
        
        // Convert encrypted bytes to hex string
        let hexString = encryptedBytes.map { String(format: "%02x", $0) }.joined()
        
        logger.debug("RSA encryption completed with PKCS#1 v1.5. Output: \(hexString.prefix(32))...")
        
        return hexString
    }
    
    private static func modulusToBytes(_ modulus: BigInt) -> [UInt8] {
        // Convert BigInt to byte array
        let data = modulus.serialize()
        return Array(data)
    }
    
    private static func exponentToBytes(_ exponent: BigInt) -> [UInt8] {
        // Convert BigInt to byte array
        let data = exponent.serialize()
        return Array(data)
    }
}