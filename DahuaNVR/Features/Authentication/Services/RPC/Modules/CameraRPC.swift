import Foundation

class CameraRPC: RPCModule {
    let rpcBase: RPCBase
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getCameraState() async throws -> [CameraState] {
        guard rpcBase.currentSessionID != nil else {
            throw RPCError(code: -1, message: "No valid session ID available for camera state request")
        }
        
        let response = try await rpcBase.sendDirectResponse(
            method: "LogicDeviceManager.getCameraState",
            params: ["uniqueChannels": AnyJSON([-1])],
            responseType: CameraStateResponse.self
        )
        
        return response.params.states
    }
    
    func getAllCameras() async throws -> [NVRCamera] {
        guard let sessionId = rpcBase.currentSessionID else {
            throw RPCError(code: -1, message: "No valid session ID available for camera request")
        }
        
        struct CameraRequest: Codable {
            let method: String
            let params: String?
            let id: Int
            let session: String
        }
        
        let cameraRequest = CameraRequest(
            method: "LogicDeviceManager.getCameraAll",
            params: nil,
            id: 1,
            session: sessionId
        )
        
        // Get both cameras and their connection states concurrently
        async let camerasTask = rpcBase.sendEncrypted(
            method: "system.multiSec",
            payload: [cameraRequest],
            handler: GetAllCamerasHandler()
        )
        async let statesTask = getCameraState()
        
        let (responses, cameraStates) = try await (camerasTask, statesTask)
        
        guard let firstResponse = responses.first else {
            throw RPCError(code: -1, message: "No camera data received from RPC")
        }
        
        // Create a dictionary for quick state lookup by channel
        let statesByChannel = Dictionary(uniqueKeysWithValues: cameraStates.map { ($0.channel, $0.connectionState) })
        
        let cameras = firstResponse.params.camera.compactMap { cameraInfo -> NVRCamera? in
            var camera = cameraInfo.toNVRCamera()
            // Map connection state to showStatus field
            if let connectionState = statesByChannel[cameraInfo.uniqueChannel] {
                camera?.showStatus = connectionState
            }
            return camera
        }
        
        return cameras
    }
    
    func secSetCamera(cameraData: [String: Any]) async throws -> [NVRCamera] {
        guard let sessionId = rpcBase.currentSessionID else {
            throw RPCError(code: -1, message: "No valid session ID available for camera update request")
        }
        
        // Create the request structure with only camera data
        let cameraRequest = try SecSetCameraRequest(cameraData: cameraData)
        
        let result = try await rpcBase.sendEncrypted(
            method: "LogicDeviceManager.secSetCamera",
            payload: cameraRequest,
            handler: SecSetCameraHandler()
        )
        
        if !result.success {
            throw RPCError(code: -1, message: "Camera update failed")
        }
        
        // Since the response doesn't contain camera data, we need to fetch updated cameras
        // This ensures UI consistency after successful update
        return try await getAllCameras()
    }
}

// MARK: - Response Handlers

private struct GetAllCamerasHandler: RPCResponseHandler {
    typealias ResponseType = [CameraResponse]
    
    func handle(rawData: Data, decryptionKey: Data?) throws -> [CameraResponse] {
        // Parse the encrypted response wrapper
        struct EncryptedResponse: Codable {
            let result: Bool
            let params: Params?
            let error: RPCError?
            let id: Int?
            let session: String?
            
            struct Params: Codable {
                let content: String
            }
        }
        
        let response = try JSONDecoder().decode(EncryptedResponse.self, from: rawData)
        
        if let error = response.error {
            throw error
        }
        
        guard response.result, let content = response.params?.content else {
            throw RPCError(code: -1, message: "No encrypted content in camera response")
        }
        
        guard let decryptionKey = decryptionKey else {
            throw RPCError(code: -1, message: "No decryption key available")
        }
        
        // Decrypt the content
        let profile = EncryptionProfile.RPAC
        let paddedKey: Data
        if decryptionKey.count < profile.keyLength {
            var keyData = decryptionKey
            keyData.append(Data(repeating: 0, count: profile.keyLength - decryptionKey.count))
            paddedKey = keyData.prefix(profile.keyLength)
        } else {
            paddedKey = decryptionKey.prefix(profile.keyLength)
        }
        
        let decryptedData = try EncryptionUtility.decryptWithAES(
            encryptedString: content,
            key: paddedKey,
            profile: profile
        )
        
        // Parse the decrypted camera data
        return try JSONDecoder().decode([CameraResponse].self, from: decryptedData)
    }
}

private struct SecSetCameraHandler: RPCResponseHandler {
    typealias ResponseType = SecSetCameraApiResult
    
    func handle(rawData: Data, decryptionKey: Data?) throws -> SecSetCameraApiResult {
        // Parse response - NO DECRYPTION NEEDED for SecSetCamera
        struct RawResponse: Codable {
            let id: Int?
            let result: Bool
            let params: Params?
            let error: ErrorInfo?
            let session: String?
            
            struct Params: Codable {
                let content: String
            }
            
            struct ErrorInfo: Codable {
                let code: Int
                let message: String
            }
        }
        
        let response = try JSONDecoder().decode(RawResponse.self, from: rawData)
        
        // Check result field for success/failure
        if !response.result {
            if let error = response.error {
                throw RPCError(code: error.code, message: error.message)
            }
            throw RPCError(code: -1, message: "SecSetCamera request failed")
        }
        
        // Return success result
        return SecSetCameraApiResult(
            success: response.result,
            content: response.params?.content,
            session: response.session
        )
    }
}

struct SecSetCameraApiResult {
    let success: Bool
    let content: String?
    let session: String?
}

struct CameraResponse: Codable {
    let params: CameraParams
}

struct CameraParams: Codable {
    let camera: [RPCCameraInfo]
}

struct CameraStateResponse: Codable {
    let id: Int
    let params: CameraStateResponseParams
    let result: Bool
    let session: String
}

struct CameraStateResponseParams: Codable {
    let states: [CameraState]
}

struct CameraState: Codable {
    let channel: Int
    let connectionState: String?
}

// MARK: - Template Request/Response Types
// These are placeholder types for demonstration. Implement actual fields based on API requirements.

struct CameraUpdateRequest: Codable {
    // TODO: Add actual fields based on camera update API requirements
    let id: String
    let name: String?
    let enabled: Bool?
}

struct CameraUpdateResponse: Codable {
    // TODO: Add actual response fields based on API
    let success: Bool
    let message: String?
}

struct CameraAddRequest: Codable {
    // TODO: Add actual fields based on camera add API requirements
    let name: String
    let address: String
    let port: Int
}

struct CameraAddResponse: Codable {
    // TODO: Add actual response fields based on API
    let id: String
    let success: Bool
    let message: String?
}

struct CameraDeleteResponse: Codable {
    // TODO: Add actual response fields based on API
    let success: Bool
    let message: String?
}

// MARK: - secSetCamera Request/Response Types

// DTO structure to match EXACT server expected JSON format
struct CameraUpdateDTO: Codable {
    let Address: String
    let AudioInputChannels: Int
    let DeviceClass: String
    let DeviceType: String
    let Enable: Bool
    let Encryption: Int
    let HttpPort: Int
    let HttpsPort: Int
    let Mac: String
    let Name: String
    let PoE: Bool
    let PoEPort: Int
    let Port: Int
    let ProtocolType: String
    let RtspPort: Int
    let SerialNo: String
    let UserName: String
    let VideoInputChannels: Int
    let VideoInputs: [VideoInputDTO]
    let Password: String
    let LoginType: Int
    let b_isMultiVideoSensor: Bool
}

struct VideoInputDTO: Codable {
    let Enable: Bool
    let ExtraStreamUrl: String
    let MainStreamUrl: String
    let Name: String
    let ServiceType: String
    let BufDelay: Int
}

struct SecSetCameraRequest: Codable {
    let cameras: [CameraPayload]
    
    init(cameraData: [String: Any]) throws {
        guard let camerasArray = cameraData["cameras"] as? [[String: Any]] else {
            throw RPCError(code: -1, message: "Invalid camera data: missing 'cameras' array")
        }
        
        // Use JSONDecoder to parse the dictionary array directly
        let camerasData = try JSONSerialization.data(withJSONObject: camerasArray)
        self.cameras = try JSONDecoder().decode([CameraPayload].self, from: camerasData)
    }
}

// Simplified payload structure that matches exact server JSON format
struct CameraPayload: Codable {
    let DeviceInfo: CameraUpdateDTO  // Use DTO directly - no conversion
    let Channel: Int
    let DeviceID: String
    let VideoStream: String
    let Enable: Bool
    let `Type`: String
    let showStatus: String
    let VideoStandard: String
    let UniqueChannel: Int
    // Removed custom init - using compiler-generated Codable
}

// Response structure for secSetCamera - API returns array directly
struct SecSetCameraRPCResponse: Codable {
    let cameras: [SecSetCameraResult]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.cameras = try container.decode([SecSetCameraResult].self)
    }
}

struct SecSetCameraResult: Codable {
    let UniqueChannel: Int
    let failedCode: Bool
}

