import Foundation

class RPCService {
    private let rpcBase: RPCBase
    private let rpcLogin: RPCLogin
    private let logger = Logger()
    
    lazy var configManager: ConfigManagerRPC = {
        ConfigManagerRPC(rpcBase: rpcBase)
    }()
    
    lazy var system: SystemRPC = {
        SystemRPC(rpcBase: rpcBase)
    }()
    
    lazy var magicBox: MagicBoxRPC = {
        MagicBoxRPC(rpcBase: rpcBase)
    }()
    
    lazy var security: SecurityRPC = {
        SecurityRPC(base: rpcBase)
    }()
    
    lazy var camera: CameraRPC = {
        CameraRPC(rpcBase: rpcBase)
    }()
    
    init(baseURL: String) {
        self.rpcBase = RPCBase(baseURL: baseURL)
        self.rpcLogin = RPCLogin(rpcBase: rpcBase)
        
        #if DEBUG
        logger.debug("Initialized RPC service for \(baseURL)")
        #endif
    }
    
    func authenticate(username: String, password: String) async throws {
        #if DEBUG
        logger.debug("Starting RPC authentication")
        #endif
        
        try await rpcLogin.login(username: username, password: password)
        
        #if DEBUG
        logger.debug("RPC authentication completed successfully")
        #endif
    }
    
    func disconnect() async throws {
        #if DEBUG
        logger.debug("Disconnecting RPC service")
        #endif
        
        try await rpcLogin.logout()
        
        #if DEBUG
        logger.debug("RPC service disconnected")
        #endif
    }
    
    var isAuthenticated: Bool {
        return rpcLogin.hasActiveSession
    }
    
    var hasActiveSession: Bool {
        return rpcBase.hasActiveSession
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[RPCService Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[RPCService Error] \(message)")
        #endif
    }
}