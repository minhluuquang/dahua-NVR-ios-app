Comprehensive Encryption Utility Implementation Plan

  Overview

  Create a hybrid encryption system for the RPC service using RSA key encapsulation and AES data encryption, compatible with Dahua NVR's encryption requirements.

  Architecture Components

  ┌─────────────────────────────────────────────────────────┐
  │                   CryptoConfiguration                    │
  │                      (Singleton)                         │
  │  - asymmetric: String                                   │
  │  - cipher: [String]                                     │
  │  - publicKey: String                                    │
  │  - parsedModulus: BigInt                               │
  │  - parsedExponent: BigInt                              │
  └─────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │                   EncryptionUtility                      │
  │  - selectProfile() → EncryptionProfile                  │
  │  - generateSymmetricKey() → Data                        │
  │  - encryptWithRSA() → String                           │
  │  - encryptWithAES() → String                           │
  │  - encrypt() → EncryptedPacket                         │
  └─────────────────────────────────────────────────────────┘
                              │
                              ▼
  ┌─────────────────────────────────────────────────────────┐
  │                    EncryptedPacket                       │
  │  - cipher: String (e.g., "RPAC-256")                   │
  │  - salt: String (hex-encoded RSA result)               │
  │  - content: String (base64-encoded AES result)         │
  └─────────────────────────────────────────────────────────┘

  Implementation Phases

  Phase 1: Foundation Setup

  1. Create Directory Structure
  DahuaNVR/Features/Authentication/Services/Encryption/
  ├── EncryptionTypes.swift
  ├── CryptoConfiguration.swift
  ├── EncryptionUtility.swift
  ├── EncryptionUtility+RSA.swift
  └── EncryptionUtility+AES.swift
  2. Define Core Types (EncryptionTypes.swift)
    - EncryptionProfile enum
        - RPAC: 32 bytes, CBC mode
      - AES: 16 bytes, ECB mode
    - EncryptedPacket struct
    - EncryptionError enum

  Phase 2: Configuration Management

  3. Implement CryptoConfiguration (CryptoConfiguration.swift)
    - Singleton pattern with thread-safe access
    - Parse RSA public key (N:hexModulus,E:hexExponent)
    - Store asymmetric type and cipher list
    - Provide computed properties for parsed values

  Phase 3: RSA Implementation

  4. RSA Key Encapsulation (EncryptionUtility+RSA.swift)
    - Parse hex strings to BigInt values
    - Implement raw RSA: ciphertext = plaintext^E mod N
    - Convert result to hexadecimal string
    - Handle BigInt operations efficiently

  Phase 4: AES Implementation

  5. AES Data Encryption (EncryptionUtility+AES.swift)
    - Implement zero-padding algorithm:
    padding = (16 - (data.count % 16)) % 16
  paddedData = data + Data(repeating: 0x00, count: padding)
    - Support both CBC and ECB modes
    - Use static IV (all zeros) for compatibility
    - Base64 encode the output

  Phase 5: Main Orchestration

  6. Complete EncryptionUtility (EncryptionUtility.swift)
    - Profile selection algorithm (match client/server ciphers)
    - Secure random key generation
    - Coordinate RSA and AES encryption
    - Error handling and logging

  Implementation Details

  Critical Algorithms

  Profile Selection:
  1. Define client profiles in order: [RPAC, AES]
  2. For each client profile:
     - Check if exists in server cipher list
     - Select first match found
     - Stop immediately after match

  RSA Encryption Flow:
  1. Generate random symmetric key (profile-specific length)
  2. Convert key to BigInt
  3. Compute: encrypted = key^exponent mod modulus
  4. Convert result to hex string

  AES Encryption Flow:
  1. JSON serialize the payload
  2. Apply zero-padding to reach block boundary
  3. Encrypt with profile-specific mode (CBC/ECB)
  4. Base64 encode the ciphertext

  Integration Points

  RPCService Usage:
  ┌─────────────────────┐
  │    RPCService       │
  │                     │
  │  let config =       │
  │  CryptoConfiguration│
  │  .shared            │
  │                     │
  │  let encrypted =    │
  │  try Encryption     │
  │  Utility.encrypt(   │
  │    payload: data,   │
  │    serverCiphers:   │
  │    config.cipher    │
  │  )                  │
  └─────────────────────┘

  Error Handling Strategy

  - Invalid RSA key format → EncryptionError.invalidPublicKey
  - No matching cipher → EncryptionError.noCipherMatch
  - Encryption failure → EncryptionError.encryptionFailed
  - Propagate errors to RPC layer with context

  Testing Approach

  1. Unit tests for each component
  2. Test vectors for RSA/AES compatibility
  3. Integration tests with mock server responses
  4. Validate output format matches expectations

  Success Criteria

  - Global access via CryptoConfiguration.shared
  - Support for both RPAC and AES profiles
  - Exact compatibility with server encryption
  - Clean API for RPC service integration
  - Comprehensive error handling
  - Well-documented, maintainable code
