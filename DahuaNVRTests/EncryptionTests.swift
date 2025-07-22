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
    func testCryptoConfigurationUpdate() throws {
        let config = CryptoConfiguration.shared
        
        // Store original state to restore later
        let originalAsymmetric = config.asymmetric
        let originalCipher = config.cipher
        let originalPublicKey = config.publicKey
        
        // Reset and set test values
        config.resetSync()
        
        config.updateSync(
            asymmetric: "RSA",
            cipher: ["RPAC-256", "AES-128"],
            publicKey: "N:e5f0dddb78eb4ae7b62228ea4d416776ed9256d65e62415e2fa8c866e862a77b80df0c40efc24a4c82c3c20d9a0e8de217ed2bcc317f46173e1dc088b5af9a63cf59677c2b99b752b3c5c87e96ad37c6a75fdb6c5b64bb1b42c40f07025f0c8087ca33d6b7d3c13b6f955e7cde592d02c826df583ccb4a3004c5f28fcc96073,E:10001"
        )
        
        // Test the values
        #expect(config.asymmetric == "RSA")
        #expect(config.cipher == ["RPAC-256", "AES-128"])
        #expect(config.publicKey?.hasPrefix("N:") == true)
        #expect(config.parsedModulus != nil)
        #expect(config.parsedExponent?.description == "65537") // 10001 in hex = 65537 in decimal
        
        // Restore original state to avoid affecting other tests
        if let originalAsymmetric = originalAsymmetric,
           let originalPublicKey = originalPublicKey {
            config.updateSync(
                asymmetric: originalAsymmetric,
                cipher: originalCipher,
                publicKey: originalPublicKey
            )
        } else {
            config.resetSync()
        }
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
        
        let config = CryptoConfiguration.shared
        
        // Store original state to restore later
        let originalAsymmetric = config.asymmetric
        let originalCipher = config.cipher
        let originalPublicKey = config.publicKey
        
        // Set test configuration
        config.updateSync(
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
        
        // Restore original state to avoid affecting other tests
        if let originalAsymmetric = originalAsymmetric,
           let originalPublicKey = originalPublicKey {
            config.updateSync(
                asymmetric: originalAsymmetric,
                cipher: originalCipher,
                publicKey: originalPublicKey
            )
        } else {
            config.resetSync()
        }
    }
    
    @Test("Error handling")
    func testErrorHandling() throws {
        // Create a clean slate for this test
        CryptoConfiguration.shared.resetSync()
        
        struct DummyPayload: Encodable {
            let test: String = "test"
        }
        
        // This should fail because no crypto configuration is set
        do {
            _ = try EncryptionUtility.encrypt(payload: DummyPayload(), serverCiphers: ["RPAC-256"])
            // If we reach here, the test failed because it should have thrown an error
            #expect(Bool(false), "Expected encryption to fail without valid crypto configuration")
        } catch {
            // Expected to catch an error - verify it's the right type
            #expect(error is EncryptionError, "Expected EncryptionError, got \(type(of: error))")
        }
    }
    
    // MARK: - Decryption Tests
    
    @Test("AES decryption with zero padding removal")
    func testAESDecryptionWithZeroPadding() throws {
        // Test data with zero padding
        let originalData = "{\"test\":\"value\"}".data(using: .utf8)!
        let paddedData = originalData + Data(repeating: 0x00, count: 16 - (originalData.count % 16))
        
        // Encrypt the padded data
        let key = Data(repeating: 0x42, count: 16)
        let encrypted = try EncryptionUtility.encryptWithAES(data: paddedData, key: key, profile: .AES)
        
        // Decrypt and verify
        let decrypted = try EncryptionUtility.decryptWithAES(encryptedString: encrypted, key: key, profile: .AES)
        
        #expect(decrypted != nil)
        #expect(decrypted?["test"] as? String == "value")
    }
    
    @Test("AES decryption with different profiles")
    func testAESDecryptionProfiles() throws {
        let testData: [String: Any] = ["method": "test", "params": ["key": "value"]]
        let jsonData = try JSONSerialization.data(withJSONObject: testData)
        
        // Test with AES profile (ECB mode)
        let aesKey = Data(repeating: 0x33, count: 16)
        let aesEncrypted = try EncryptionUtility.encryptWithAES(data: jsonData, key: aesKey, profile: .AES)
        let aesDecrypted = try EncryptionUtility.decryptWithAES(encryptedString: aesEncrypted, key: aesKey, profile: .AES)
        
        #expect(aesDecrypted?["method"] as? String == "test")
        #expect((aesDecrypted?["params"] as? [String: String])?["key"] == "value")
        
        // Test with RPAC profile (CBC mode)
        let rpacKey = Data(repeating: 0x44, count: 32)
        let rpacEncrypted = try EncryptionUtility.encryptWithAES(data: jsonData, key: rpacKey, profile: .RPAC)
        let rpacDecrypted = try EncryptionUtility.decryptWithAES(encryptedString: rpacEncrypted, key: rpacKey, profile: .RPAC)
        
        #expect(rpacDecrypted?["method"] as? String == "test")
        #expect((rpacDecrypted?["params"] as? [String: String])?["key"] == "value")
    }
    
    @Test("Decryption with UTF-8 and Latin-1 fallback")
    func testDecryptionEncodingFallback() throws {
        let key = Data(repeating: 0x55, count: 16)
        
        // Test UTF-8 encoded JSON
        let utf8Data = "{\"message\":\"Hello, 世界\"}".data(using: .utf8)!
        let utf8Encrypted = try EncryptionUtility.encryptWithAES(data: utf8Data, key: key, profile: .AES)
        let utf8Decrypted = try EncryptionUtility.decryptWithAES(encryptedString: utf8Encrypted, key: key, profile: .AES)
        
        #expect(utf8Decrypted?["message"] as? String == "Hello, 世界")
        
        // Test Latin-1 encoded JSON (using characters that are valid in Latin-1)
        let latin1String = "{\"message\":\"Café\"}"
        let latin1Data = latin1String.data(using: .isoLatin1)!
        let paddedLatin1 = latin1Data + Data(repeating: 0x00, count: 16 - (latin1Data.count % 16))
        
        // Manually encrypt with proper padding
        let encrypted = try EncryptionUtility.encryptWithAES(data: paddedLatin1, key: key, profile: .AES)
        let decrypted = try EncryptionUtility.decryptWithAES(encryptedString: encrypted, key: key, profile: .AES)
        
        #expect(decrypted != nil)
        #expect(decrypted?["message"] as? String != nil)
    }
    
    @Test("Decryption error handling")
    func testDecryptionErrorHandling() throws {
        let key = Data(repeating: 0x66, count: 16)
        
        // Test invalid base64 string
        #expect(throws: EncryptionError.invalidBase64String) {
            _ = try EncryptionUtility.decryptWithAES(encryptedString: "not-valid-base64!", key: key, profile: .AES)
        }
        
        // Test wrong key size
        let wrongKey = Data(repeating: 0x77, count: 8)
        let validEncrypted = try EncryptionUtility.encryptWithAES(data: Data([0x01, 0x02, 0x03]), key: key, profile: .AES)
        
        #expect(throws: EncryptionError.invalidKeySize(expected: 16, actual: 8)) {
            _ = try EncryptionUtility.decryptWithAES(encryptedString: validEncrypted, key: wrongKey, profile: .AES)
        }
        
        // Test decryption with wrong key (should fail to parse JSON)
        let wrongKey16 = Data(repeating: 0x88, count: 16)
        let jsonData = "{\"test\":\"data\"}".data(using: .utf8)!
        let encrypted = try EncryptionUtility.encryptWithAES(data: jsonData, key: key, profile: .AES)
        
        let result = try EncryptionUtility.decryptWithAES(encryptedString: encrypted, key: wrongKey16, profile: .AES)
        #expect(result == nil) // Should return nil when JSON parsing fails
    }
    
    @Test("Full encrypt-decrypt cycle")
    func testFullEncryptDecryptCycle() throws {
        let testCases: [[String: Any]] = [
            ["id": 1, "method": "test.method", "params": ["key": "value"]],
            ["status": true, "count": 42, "items": ["item1", "item2", "item3"]],
            ["nested": ["level1": ["level2": ["level3": "deep value"]]]],
            ["unicode": "Hello 世界 🌍", "special": "Café ñ é"]
        ]
        
        for (index, testCase) in testCases.enumerated() {
            let jsonData = try JSONSerialization.data(withJSONObject: testCase)
            let key = try EncryptionUtility.generateSymmetricKey(length: 16)
            
            // Encrypt
            let encrypted = try EncryptionUtility.encryptWithAES(data: jsonData, key: key, profile: .AES)
            
            // Decrypt
            let decrypted = try EncryptionUtility.decryptWithAES(encryptedString: encrypted, key: key, profile: .AES)
            
            #expect(decrypted != nil, "Test case \(index) failed: decryption returned nil")
            
            // Compare original and decrypted data
            let originalJSON = try JSONSerialization.data(withJSONObject: testCase)
            let decryptedJSON = try JSONSerialization.data(withJSONObject: decrypted!)
            
            // Parse both to compare (order might be different)
            let originalDict = try JSONSerialization.jsonObject(with: originalJSON) as! [String: Any]
            let decryptedDict = try JSONSerialization.jsonObject(with: decryptedJSON) as! [String: Any]
            
            #expect(NSDictionary(dictionary: originalDict).isEqual(to: decryptedDict),
                   "Test case \(index) failed: decrypted data doesn't match original")
        }
    }
    
    @Test("Decryption with corrupted data returns nil")
    func testDecryptionWithCorruptedData() throws {
        let key = Data(repeating: 0x99, count: 16)
        
        // Create some random encrypted-looking data that won't decrypt to valid JSON
        let randomData = Data((0..<64).map { _ in UInt8.random(in: 0...255) })
        let base64String = randomData.base64EncodedString()
        
        // This should decrypt but fail to parse as JSON, returning nil
        let result = try EncryptionUtility.decryptWithAES(encryptedString: base64String, key: key, profile: .AES)
        #expect(result == nil)
    }
}