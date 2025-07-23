//
//  CryptoConfiguration.swift
//  DahuaNVR
//
//  Singleton for managing global crypto configuration
//

import Foundation
import BigInt
import os.log

public final class CryptoConfiguration {
    
    private static let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CryptoConfiguration")
    
    public static let shared = CryptoConfiguration()
    
    private let queue = DispatchQueue(label: "com.dahuanvr.cryptoconfiguration", attributes: .concurrent)
    
    private var _asymmetric: String?
    private var _cipher: [String] = []
    private var _publicKey: String?
    
    private var _parsedModulus: BigUInt?
    private var _parsedExponent: BigUInt?
    
    private init() {}
    
    public var asymmetric: String? {
        queue.sync { _asymmetric }
    }
    
    public var cipher: [String] {
        queue.sync { _cipher }
    }
    
    public var publicKey: String? {
        queue.sync { _publicKey }
    }
    
    public var parsedModulus: BigUInt? {
        queue.sync { _parsedModulus }
    }
    
    public var parsedExponent: BigUInt? {
        queue.sync { _parsedExponent }
    }
    
    public func update(asymmetric: String? = nil, cipher: [String]? = nil, publicKey: String? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let asymmetric = asymmetric {
                self._asymmetric = asymmetric
                Self.logger.debug("Updated asymmetric algorithm: \(asymmetric)")
            }
            
            if let cipher = cipher {
                self._cipher = cipher
                Self.logger.debug("Updated cipher list: \(cipher.joined(separator: ", "))")
            }
            
            if let publicKey = publicKey {
                self._publicKey = publicKey
                self.parsePublicKey(publicKey)
            }
        }
    }
    
    private func parsePublicKey(_ publicKey: String) {
        Self.logger.debug("Parsing RSA public key: \(publicKey)")
        
        let components = publicKey.split(separator: ",")
        guard components.count == 2 else {
            Self.logger.error("Invalid public key format. Expected 'N:modulus,E:exponent'")
            return
        }
        
        let modulusComponent = components[0]
        let exponentComponent = components[1]
        
        guard modulusComponent.hasPrefix("N:"),
              exponentComponent.hasPrefix("E:") else {
            Self.logger.error("Invalid public key format. Missing N: or E: prefix")
            return
        }
        
        let modulusHex = String(modulusComponent.dropFirst(2))
        let exponentHex = String(exponentComponent.dropFirst(2))
        
        guard let modulus = BigUInt(modulusHex, radix: 16),
              let exponent = BigUInt(exponentHex, radix: 16) else {
            Self.logger.error("Failed to parse hex values from public key")
            return
        }
        
        _parsedModulus = modulus
        _parsedExponent = exponent
        
        Self.logger.debug("Successfully parsed RSA public key")
        Self.logger.debug("Modulus bits: \(modulus.bitWidth)")
        Self.logger.debug("Exponent: \(exponent)")
    }
    
    public func reset() {
        queue.async(flags: .barrier) { [weak self] in
            self?._asymmetric = nil
            self?._cipher = []
            self?._publicKey = nil
            self?._parsedModulus = nil
            self?._parsedExponent = nil
            Self.logger.debug("Reset crypto configuration")
        }
    }
    
    #if DEBUG
    public func resetSync() {
        queue.sync(flags: .barrier) { [weak self] in
            self?._asymmetric = nil
            self?._cipher = []
            self?._publicKey = nil
            self?._parsedModulus = nil
            self?._parsedExponent = nil
            Self.logger.debug("Reset crypto configuration synchronously")
        }
    }
    
    public func updateSync(asymmetric: String? = nil, cipher: [String]? = nil, publicKey: String? = nil) {
        queue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if let asymmetric = asymmetric {
                self._asymmetric = asymmetric
                Self.logger.debug("Updated asymmetric algorithm: \(asymmetric)")
            }
            
            if let cipher = cipher {
                self._cipher = cipher
                Self.logger.debug("Updated cipher list: \(cipher.joined(separator: ", "))")
            }
            
            if let publicKey = publicKey {
                self._publicKey = publicKey
                self.parsePublicKey(publicKey)
            }
        }
    }
    #endif
}
