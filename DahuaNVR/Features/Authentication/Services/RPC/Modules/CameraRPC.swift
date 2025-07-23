import Foundation
import os.log

class CameraRPC: RPCModule {
    let rpcBase: RPCBase
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "CameraRPC")
    private var lastUsedSymmetricKey: Data?
    
    required init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    func getAllCameras() async throws -> [NVRCamera] {
        #if DEBUG
        logger.debug("🎥 RPC Camera: Getting all cameras via encrypted RPC")
        #endif
        
        guard rpcBase.hasActiveSession else {
            throw RPCError(code: -1, message: "No active RPC session for camera request")
        }
        
        guard let sessionId = rpcBase.currentSessionID else {
            throw RPCError(code: -1, message: "No valid session ID available for camera request")
        }
        
        #if DEBUG
        logger.debug("   → Using session ID: \(sessionId)")
        #endif
        
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
        
        let payload = [cameraRequest]
        
        let encryptedPacket = try EncryptionUtility.encrypt(
            payload: payload,
            serverCiphers: ["RPAC-256"]
        )
        
        self.lastUsedSymmetricKey = Data(encryptedPacket.salt.utf8)
        
        #if DEBUG
        logger.debug("   → Payload encrypted successfully")
        logger.debug("   → Cipher: \(encryptedPacket.cipher)")
        logger.debug("   → Salt length: \(encryptedPacket.salt.count) chars")
        logger.debug("   → Content length: \(encryptedPacket.content.count) chars")
        #endif
        
        let params: [String: AnyJSON] = [
            "salt": AnyJSON(encryptedPacket.salt),
            "cipher": AnyJSON(encryptedPacket.cipher),
            "content": AnyJSON(encryptedPacket.content)
        ]
        
        let response: RPCResponse<SystemMultiSecResponse> = try await rpcBase.send(
            method: "system.multiSec",
            params: params,
            responseType: SystemMultiSecResponse.self
        )
        
        guard let responseData = response.result ?? response.params else {
            throw RPCError(code: -1, message: "No camera data received from RPC")
        }
        
        #if DEBUG
        logger.debug("   → Encrypted response received")
        logger.debug("   → Content length: \(responseData.content.count) chars")
        #endif
        
        guard let symmetricKey = lastUsedSymmetricKey else {
            throw RPCError(code: -1, message: "No symmetric key available for decryption")
        }
        
        let decryptedData = try decryptCameraResponse(
            encryptedContent: responseData.content,
            key: symmetricKey
        )
        
        #if DEBUG
        logger.debug("   → Response decrypted successfully")
        #endif
        
        return try parseCameraData(from: decryptedData)
    }
    
    private func decryptCameraResponse(encryptedContent: String, key: Data) throws -> Any {
        let profile = EncryptionProfile.RPAC
        
        let paddedKey: Data
        if key.count < profile.keyLength {
            var keyData = key
            keyData.append(Data(repeating: 0, count: profile.keyLength - key.count))
            paddedKey = keyData.prefix(profile.keyLength)
        } else {
            paddedKey = key.prefix(profile.keyLength)
        }
        
        return try EncryptionUtility.decryptWithAES(
            encryptedString: encryptedContent,
            key: paddedKey,
            profile: profile
        ) ?? [:]
    }
    
    private func parseCameraData(from decryptedData: Any) throws -> [NVRCamera] {
        #if DEBUG
        logger.debug("   → Parsing decrypted camera data")
        logger.debug("   → Data type: \(type(of: decryptedData))")
        #endif
        
        if let jsonArray = decryptedData as? [[String: Any]] {
            return try parseFromArray(jsonArray)
        } else if let jsonDict = decryptedData as? [String: Any] {
            if let results = jsonDict["camera"] as? [[String: Any]] {
                return try parseFromCameraArray(results)
            } else if let firstResult = jsonDict.values.first as? [String: Any],
                      let cameraData = firstResult["params"] as? [String: Any],
                      let cameraArray = cameraData["camera"] as? [[String: Any]] {
                return try parseFromCameraArray(cameraArray)
            }
        }
        
        throw RPCError(code: -1, message: "Unable to parse camera data from decrypted response")
    }
    
    private func parseFromArray(_ jsonArray: [[String: Any]]) throws -> [NVRCamera] {
        guard let firstResponse = jsonArray.first,
              let paramsDict = firstResponse["params"] as? [String: Any],
              let cameraArray = paramsDict["camera"] as? [[String: Any]] else {
            throw RPCError(code: -1, message: "Invalid camera response array format")
        }
        
        return try parseFromCameraArray(cameraArray)
    }
    
    private func parseFromCameraArray(_ cameraArray: [[String: Any]]) throws -> [NVRCamera] {
        #if DEBUG
        logger.debug("   → Found \(cameraArray.count) cameras in response")
        #endif
        
        var cameras: [NVRCamera] = []
        
        for (index, cameraDict) in cameraArray.enumerated() {
            do {
                let cameraData = try JSONSerialization.data(withJSONObject: cameraDict)
                let rpcCamera = try JSONDecoder().decode(RPCCameraInfo.self, from: cameraData)
                let nvrCamera = rpcCamera.toNVRCamera()
                cameras.append(nvrCamera)
                
                #if DEBUG
                logger.debug("   → Camera \(index + 1): \(nvrCamera.name) (\(nvrCamera.deviceInfo.address)) - \(nvrCamera.enable ? "Enabled" : "Disabled")")
                #endif
            } catch {
                #if DEBUG
                logger.warning("⚠️ Failed to parse camera \(index + 1): \(error.localizedDescription)")
                logger.warning("   → Camera data: \(cameraDict)")
                #endif
                continue
            }
        }
        
        #if DEBUG
        logger.debug("✅ Successfully retrieved \(cameras.count) cameras via RPC")
        #endif
        
        return cameras
    }
}

struct SystemMultiSecResponse: Codable {
    let content: String
    
    private enum CodingKeys: String, CodingKey {
        case content
    }
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
