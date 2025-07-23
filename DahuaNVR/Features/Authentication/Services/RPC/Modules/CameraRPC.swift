import Foundation
import os.log

class CameraRPC: RPCModule, EncryptedRPCModule {
    let rpcBase: RPCBase
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraRPC")
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getAllCameras() async throws -> [NVRCamera] {
        #if DEBUG
        logger.debug("🎥 RPC Camera: Getting all cameras via encrypted RPC")
        #endif
        
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
        
        // Simplified - no encryption logic needed
        let responses = try await sendEncrypted(
            method: "LogicDeviceManager.getCameraAll",
            payload: [cameraRequest],
            responseType: [CameraResponse].self
        )
        
        guard let firstResponse = responses.first else {
            throw RPCError(code: -1, message: "No camera data received from RPC")
        }
        
        let cameras = firstResponse.params.camera.map { $0.toNVRCamera() }
        
        #if DEBUG
        logger.debug("✅ Successfully retrieved \(cameras.count) cameras via RPC")
        #endif
        
        return cameras
    }
    
    // MARK: - Future API Templates - Adding New Encrypted APIs
    
    // Template for camera update operations - only 2 lines needed!
    func updateCamera(_ camera: CameraUpdateRequest) async throws -> CameraUpdateResponse {
        return try await sendEncrypted(
            method: "LogicDeviceManager.updateCamera",
            payload: camera,
            responseType: CameraUpdateResponse.self
        )
    }
    
    // Template for camera addition operations - only 2 lines needed!
    func addCamera(_ camera: CameraAddRequest) async throws -> CameraAddResponse {
        return try await sendEncrypted(
            method: "LogicDeviceManager.addCamera",
            payload: camera,
            responseType: CameraAddResponse.self
        )
    }
    
    // Template for camera deletion operations - only 2 lines needed!
    func deleteCamera(id: String) async throws -> CameraDeleteResponse {
        return try await sendEncrypted(
            method: "LogicDeviceManager.deleteCamera",
            payload: ["id": id],
            responseType: CameraDeleteResponse.self
        )
    }
}

struct CameraResponse: Codable {
    let params: CameraParams
}

struct CameraParams: Codable {
    let camera: [RPCCameraInfo]
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

private struct Logger {
    let osLogger: os.Logger
    
    init(subsystem: String, category: String) {
        self.osLogger = os.Logger(subsystem: subsystem, category: category)
    }
    
    func debug(_ message: String) {
        #if DEBUG
        osLogger.debug("\(message, privacy: .public)")
        #endif
    }
    
    func warning(_ message: String) {
        #if DEBUG
        osLogger.warning("\(message, privacy: .public)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        osLogger.error("\(message, privacy: .public)")
        #endif
    }
}
