//
//  SecurityRPC.swift
//  DahuaNVR
//
//  Security-related RPC operations
//

import Foundation
import os.log

enum SecurityError: Error {
    case missingEncryptionInfo
}

public class SecurityRPC {
    private let base: RPCBase
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "SecurityRPC")
    
    init(base: RPCBase) {
        self.base = base
    }
    
    public struct EncryptInfo: Codable {
        let asymmetric: String
        let cipher: [String]
        let pub: String
    }
    
    // Special response structure for getEncryptInfo that has boolean result
    private struct EncryptInfoResponse: Codable {
        let params: EncryptInfo?
        let result: Bool
    }
    
    public func getEncryptInfo() async throws -> EncryptInfo {
        logger.debug("Fetching encryption info from NVR")
        
        // Use OutsideCmd endpoint for getEncryptInfo as shown in the curl example
        logger.debug("Using OutsideCmd endpoint for Security.getEncryptInfo")
        
        // Use sendOutsideCmdDirect to decode the response directly as EncryptInfoResponse
        let response = try await base.sendOutsideCmdDirect(
            method: "Security.getEncryptInfo", 
            params: nil,
            responseType: EncryptInfoResponse.self
        )
        
        // For getEncryptInfo, the result is typically a boolean true when successful
        // The actual data is in params
        guard let params = response.params else {
            logger.error("Security.getEncryptInfo returned no params")
            throw SecurityError.missingEncryptionInfo
        }
        
        logger.debug("Successfully retrieved encryption info")
        logger.debug("Asymmetric: \(params.asymmetric)")
        logger.debug("Ciphers: \(params.cipher.joined(separator: ", "))")
        
        // Update global crypto configuration
        CryptoConfiguration.shared.update(
            asymmetric: params.asymmetric,
            cipher: params.cipher,
            publicKey: params.pub
        )
        
        return params
    }
}