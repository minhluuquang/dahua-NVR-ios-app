//
//  SecurityRPCTests.swift
//  DahuaNVRTests
//
//  Tests for SecurityRPC module
//

import Testing
import Foundation
@testable import DahuaNVR

@Suite("Security RPC Tests")
struct SecurityRPCTests {
    
    @Test("SecurityRPC.EncryptInfo structure")
    func testEncryptInfoStructure() {
        // Test that EncryptInfo can be created and has correct properties
        let encryptInfo = SecurityRPC.EncryptInfo(
            asymmetric: "RSA",
            cipher: ["AES", "RPAC"],
            pub: "N:123,E:010001"
        )
        
        #expect(encryptInfo.asymmetric == "RSA")
        #expect(encryptInfo.cipher.count == 2)
        #expect(encryptInfo.cipher[0] == "AES")
        #expect(encryptInfo.cipher[1] == "RPAC")
        #expect(encryptInfo.pub == "N:123,E:010001")
    }
    
    @Test("CryptoConfiguration public key parsing")
    func testCryptoConfigurationParsing() throws {
        // Reset crypto configuration first
        CryptoConfiguration.shared.resetSync()
        
        // Update with a valid RSA public key
        CryptoConfiguration.shared.updateSync(
            asymmetric: "RSA",
            cipher: ["AES", "RPAC"],
            publicKey: "N:123,E:010001"
        )
        
        // Verify values were set
        #expect(CryptoConfiguration.shared.asymmetric == "RSA")
        #expect(CryptoConfiguration.shared.cipher == ["AES", "RPAC"])
        #expect(CryptoConfiguration.shared.publicKey == "N:123,E:010001")
        #expect(CryptoConfiguration.shared.parsedModulus != nil)
        #expect(CryptoConfiguration.shared.parsedExponent != nil)
        
        // Clean up
        CryptoConfiguration.shared.resetSync()
    }
}