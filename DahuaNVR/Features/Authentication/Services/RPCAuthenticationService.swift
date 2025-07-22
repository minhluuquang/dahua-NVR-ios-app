import Foundation
import os.log

class RPCAuthenticationService: ObservableObject {
    private let rpcService: RPCService
    private let logger = Logger(subsystem: "com.minhlq.DahuaNVR", category: "RPCAuthenticationService")
    
    let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
        self.rpcService = RPCService(baseURL: baseURL)
    }
    
    func authenticate(with credentials: NVRCredentials) async -> RPCAuthenticationResult {
        #if DEBUG
        logger.debug("🔐 RPC-Only Authentication Starting")
        logger.debug("   → Server: \(credentials.serverURL)")
        logger.debug("   → Username: \(credentials.username)")
        #endif
        
        do {
            try await rpcService.authenticate(username: credentials.username, password: credentials.password)
            
            let result = RPCAuthenticationResult(
                success: true,
                error: nil
            )
            
            #if DEBUG
            logger.debug("✅ RPC Authentication Successful")
            #endif
            
            return result
        } catch {
            #if DEBUG
            logger.error("❌ RPC Authentication Error: \(error.localizedDescription)")
            #endif
            
            return RPCAuthenticationResult(
                success: false,
                error: error
            )
        }
    }
    
    // Camera access through RPC
    func getCameras() async throws -> [NVRCamera] {
        guard rpcService.hasActiveSession else {
            throw RPCAuthenticationError.noActiveSession
        }
        
        return try await rpcService.camera.getAllCameras()
    }
    
    // Direct access to RPC modules for advanced operations
    var rpc: RPCService {
        rpcService
    }
}

struct RPCAuthenticationResult {
    let success: Bool
    let error: Error?
}

enum RPCAuthenticationError: LocalizedError {
    case noActiveSession
    
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active RPC session available"
        }
    }
}