# Comprehensive Refactoring Plan: CameraRPC Encrypted API Architecture

## Executive Summary

This plan addresses critical architectural flaws in the CameraRPC module to support:

- Single-use symmetric keys per API call
- Multiple encrypted APIs with minimal code duplication
- Parallel API requests without race conditions

---

## Plan Overview

| PHASE 1: Foundation | PHASE 2: Abstraction | PHASE 3: Validation |
|---------------------|----------------------|---------------------|
| [Critical Fixes]    | [Extensible Design]  | [Production Ready]  |
| Steps 3-4           | Steps 5-6            | Steps 7-8           |

---

## PHASE 1: Foundation – Fix Critical Core Issues

### Step 3: Audit and Extend EncryptionUtility

**Task 3A: Audit Current Usage**
- Search codebase for all `EncryptionUtility.encrypt()` calls
- Document current usage patterns
- Identify breaking change risks

**Task 3B: Add Backward-Compatible API**

```swift
// New method alongside existing one
static func encryptWithKey(payload: Encodable, serverCiphers: [String]) throws -> (packet: EncryptedPacket, key: Data) {
    // Same logic as encrypt() but return both packet and symmetric key
}
```

**Success Criteria:**
- Complete usage inventory documented
- New API returns raw symmetric key
- Existing code remains unaffected

---

### Step 4: Eliminate Stateful Key Storage in CameraRPC

**Task 4A: Remove Instance Variable**

```swift
class CameraRPC: RPCModule {
    let rpcBase: RPCBase
    // REMOVE: private var lastUsedSymmetricKey: Data?
}
```

**Task 4B: Implement Request-Scoped Keys**

```swift
func getAllCameras() async throws -> [NVRCamera] {
    // Generate fresh key for this request only
    let (packet, key) = try EncryptionUtility.encryptWithKey(...)

    // Use key immediately for decryption
    let decryptedData = try decryptCameraResponse(
        encryptedContent: responseData.content,
        key: key  // Request-scoped, never stored
    )
    // Key automatically deallocated when function exits
}
```

**Success Criteria:**
- No shared encryption state between API calls
- Each request uses unique symmetric key
- Thread-safe concurrent execution

---

## PHASE 2: Create Extensible Abstraction Layer

### Step 5: Design Generic Encrypted API Interface

**Task 5A: Define Protocol**

```swift
protocol EncryptedRPCModule {
    var rpcBase: RPCBase { get }
}
```

**Task 5B: Implement Generic Handler**

```swift
extension EncryptedRPCModule {
    func sendEncrypted<TRequest: Codable, TResponse: Codable>(
        method: String,
        payload: TRequest,
        responseType: TResponse.Type
    ) async throws -> TResponse
}
```

```swift
extension RPCBase {
    func sendEncrypted<T: Codable>(
        method: String,
        payload: Codable,
        responseType: T.Type
    ) async throws -> T {
        // 1. Generate fresh key for this request
        let (packet, key) = try EncryptionUtility.encryptWithKey(...)

        // 2. Send via system.multiSec endpoint
        let response = try await send(method: "system.multiSec", ...)

        // 3. Decrypt response with same key
        let decrypted = try decryptResponse(response.content, key: key)

        // 4. Key automatically deallocated
        return try JSONDecoder().decode(T.self, from: decrypted)
    }
}
```

**Success Criteria:**
- Single generic handler for all encrypted APIs
- Automatic key lifecycle management
- Type-safe request/response handling

---

### Step 6: Refactor CameraRPC to Use Abstraction

**Task 6A: Adopt New Protocol**

```swift
class CameraRPC: RPCModule, EncryptedRPCModule {
    let rpcBase: RPCBase

    func getAllCameras() async throws -> [NVRCamera] {
        let cameraRequest = CameraRequest(...)

        // Simplified - no encryption logic needed
        let response = try await sendEncrypted(
            method: "LogicDeviceManager.getCameraAll",
            payload: [cameraRequest],
            responseType: [RPCCameraResponse].self
        )

        return response.map { $0.toNVRCamera() }
    }
}
```

**Task 6B: Clean Up Legacy Code**
- Remove all manual encryption/decryption logic
- Remove custom key padding/truncation methods
- Simplify response parsing

**Success Criteria:**
- CameraRPC becomes stateless and focused
- 80% reduction in encryption-related code
- Maintainable and readable implementation

---

## PHASE 3: Enable Future APIs and Validation

### Step 7: Create Implementation Templates

**Task 7A: Demonstrate Easy API Addition**

```swift
// Adding new encrypted APIs - only 2 lines needed!
extension CameraRPC {
    func updateCamera(_ camera: CameraUpdateRequest) async throws -> CameraUpdateResponse {
        return try await sendEncrypted(
            method: "LogicDeviceManager.updateCamera",
            payload: camera,
            responseType: CameraUpdateResponse.self
        )
    }

    func addCamera(_ camera: CameraAddRequest) async throws -> CameraAddResponse {
        return try await sendEncrypted(
            method: "LogicDeviceManager.addCamera",
            payload: camera,
            responseType: CameraAddResponse.self
        )
    }
}
```

**Task 7B: Documentation**

### Adding New Encrypted APIs – Developer Guide

#### Steps:
1. Make RPC module conform to `EncryptedRPCModule`
2. Use `sendEncrypted()` with payload and response types
3. Done! Key management handled automatically

#### Requirements:
- Payload must be Codable
- Response must be Codable
- API uses system.multiSec endpoint

**Success Criteria:**
- New encrypted APIs require <5 lines of code
- Clear documentation for developers
- Proven pattern for future expansion

---

### Step 8: Comprehensive Testing and Validation

**Task 8A: Concurrent Testing**

```swift
func testParallelEncryptedCalls() async {
    await withTaskGroup(of: [NVRCamera].self) { group in
        for _ in 0..<10 {
            group.addTask {
                try! await camera.getAllCameras()
            }
        }
        // Verify all calls succeed with unique keys
    }
}
```

**Task 8B: Integration Testing**
- Full authentication flow validation
- Backward compatibility verification
- Error handling and edge cases

**Task 8C: Final Requirements Validation**

#### REQUIREMENT CHECKLIST:
- [x] Single-use symmetric keys per API call
- [x] Support for multiple encrypted APIs
- [x] Parallel API request capability
- [x] No security regressions
- [x] Maintainable architecture
- [x] Performance preservation

**Success Criteria:**
- All parallel tests pass
- No functionality regressions
- Production deployment ready

---

## Implementation Dependencies

```
EncryptionUtility Changes (Step 3)
            |
            v
CameraRPC State Removal (Step 4)
            |
            v
Protocol Design (Step 5)
            |
            v
CameraRPC Refactor (Step 6)
            |
            v
Future API Templates (Step 7)
            |
            v
Testing & Validation (Step 8)
```

---

## Risk Mitigation

- **High Risk:** EncryptionUtility API changes  
  _Mitigation:_ Backward-compatible extension method

- **Medium Risk:** Protocol complexity  
  _Mitigation:_ Start simple, iterate based on usage

- **Low Risk:** Performance impact  
  _Mitigation:_ Benchmark at each phase

---

This plan transforms the current broken architecture into a robust, extensible system that meets all requirements while maintaining security and performance standards.
