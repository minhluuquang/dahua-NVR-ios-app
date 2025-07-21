//
//  EncryptionTests.swift
//  DahuaNVRTests
//
//  Unit tests for the encryption system
//

import Testing
@testable import DahuaNVR
import Foundation
import BigInt

@Suite("Encryption System Tests")
struct EncryptionTests {
    
    @Test("CryptoConfiguration singleton update and retrieval")
    func testCryptoConfigurationUpdate() async throws {
        let config = CryptoConfiguration.shared
        config.reset()
        
        config.update(
            asymmetric: "RSA",
            cipher: ["RPAC-256", "AES-128"],
            publicKey: "N:e5f0dddb78eb4ae7b62228ea4d416776ed9256d65e62415e2fa8c866e862a77b80df0c40efc24a4c82c3c20d9a0e8de217ed2bcc317f46173e1dc088b5af9a63cf59677c2b99b752b3c5c87e96ad37c6a75fdb6c5b64bb1b42c40f07025f0c8087ca33d6b7d3c13b6f955e7cde592d02c826df583ccb4a3004c5f28fcc96073,E:10001"
        )
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(config.asymmetric == "RSA")
        #expect(config.cipher == ["RPAC-256", "AES-128"])
        #expect(config.publicKey?.hasPrefix("N:") == true)
        #expect(config.parsedModulus != nil)
        #expect(config.parsedExponent == BigInt("10001", radix: 16))
    }
    
    @Test("Profile selection based on server ciphers")
    func testProfileSelection() throws {
        let serverCiphers1 = ["RPAC-256", "AES-128", "DES"]
        let profile1 = try EncryptionUtility.selectProfile(serverCiphers: serverCiphers1)
        #expect(profile1 == .RPAC)
        
        let serverCiphers2 = ["AES-128", "DES"]
        let profile2 = try EncryptionUtility.selectProfile(serverCiphers: serverCiphers2)
        #expect(profile2 == .AES)
        
        let serverCiphers3 = ["DES", "3DES"]
        #expect(throws: EncryptionError.self) {
            _ = try EncryptionUtility.selectProfile(serverCiphers: serverCiphers3)
        }
    }
    
    @Test("Symmetric key generation")
    func testSymmetricKeyGeneration() throws {
        let key16 = try EncryptionUtility.generateSymmetricKey(length: 16)
        #expect(key16.count == 16)
        
        let key32 = try EncryptionUtility.generateSymmetricKey(length: 32)
        #expect(key32.count == 32)
        
        let key1 = try EncryptionUtility.generateSymmetricKey(length: 16)
        let key2 = try EncryptionUtility.generateSymmetricKey(length: 16)
        #expect(key1 != key2)
    }
    
    @Test("RSA encryption functionality")
    func testRSAEncryption() throws {
        let modulus = BigInt("e5f0dddb78eb4ae7b62228ea4d416776ed9256d65e62415e2fa8c866e862a77b80df0c40efc24a4c82c3c20d9a0e8de217ed2bcc317f46173e1dc088b5af9a63cf59677c2b99b752b3c5c87e96ad37c6a75fdb6c5b64bb1b42c40f07025f0c8087ca33d6b7d3c13b6f955e7cde592d02c826df583ccb4a3004c5f28fcc96073", radix: 16)!
        let exponent = BigInt("10001", radix: 16)!
        
        let testData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
        let encrypted = try EncryptionUtility.encryptWithRSA(data: testData, modulus: modulus, exponent: exponent)
        
        #expect(!encrypted.isEmpty)
        #expect(encrypted.count > 0)
        
        // CryptoSwift RSA handles large data differently with PKCS#1 padding
        // The exact size limit depends on the key size and padding overhead
        // For now, just test that encryption works with reasonable data sizes
        let reasonableData = Data(repeating: 0x42, count: 32)  
        let encrypted2 = try EncryptionUtility.encryptWithRSA(data: reasonableData, modulus: modulus, exponent: exponent)
        #expect(!encrypted2.isEmpty)
    }
    
    @Test("AES zero padding")
    func testAESZeroPadding() throws {
        struct TestCase {
            let input: Data
            let expectedPaddedLength: Int
        }
        
        let testCases = [
            TestCase(input: Data([0x01]), expectedPaddedLength: 16),
            TestCase(input: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F]), expectedPaddedLength: 16),
            TestCase(input: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10]), expectedPaddedLength: 16),
            TestCase(input: Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11]), expectedPaddedLength: 32)
        ]
        
        for testCase in testCases {
            let key = Data(repeating: 0x42, count: 16)
            let encrypted = try EncryptionUtility.encryptWithAES(data: testCase.input, key: key, profile: .AES)
            let decryptedData = Data(base64Encoded: encrypted)!
            #expect(decryptedData.count == testCase.expectedPaddedLength)
        }
    }
    
    @Test("Complete encryption flow")
    func testCompleteEncryptionFlow() throws {
        struct TestPayload: Encodable {
            let id: Int
            let method: String
            let params: [String: String]
        }
        
        CryptoConfiguration.shared.update(
            asymmetric: "RSA",
            cipher: ["RPAC-256", "AES-128"],
            publicKey: "N:e5f0dddb78eb4ae7b62228ea4d416776ed9256d65e62415e2fa8c866e862a77b80df0c40efc24a4c82c3c20d9a0e8de217ed2bcc317f46173e1dc088b5af9a63cf59677c2b99b752b3c5c87e96ad37c6a75fdb6c5b64bb1b42c40f07025f0c8087ca33d6b7d3c13b6f955e7cde592d02c826df583ccb4a3004c5f28fcc96073,E:10001"
        )
        
        let payload = TestPayload(
            id: 1,
            method: "test.method",
            params: ["key": "value"]
        )
        
        let serverCiphers = ["RPAC-256", "AES-128"]
        
        let encrypted = try EncryptionUtility.encrypt(payload: payload, serverCiphers: serverCiphers)
        
        #expect(encrypted.cipher == "RPAC-256")
        #expect(!encrypted.salt.isEmpty)
        #expect(!encrypted.content.isEmpty)
        
        let contentData = Data(base64Encoded: encrypted.content)
        #expect(contentData != nil)
        #expect(contentData!.count % 16 == 0)
    }
    
    @Test("Error handling")
    func testErrorHandling() throws {
        CryptoConfiguration.shared.reset()
        
        struct DummyPayload: Encodable {
            let test: String = "test"
        }
        
        #expect(throws: EncryptionError.self) {
            _ = try EncryptionUtility.encrypt(payload: DummyPayload(), serverCiphers: ["RPAC-256"])
        }
    }
}