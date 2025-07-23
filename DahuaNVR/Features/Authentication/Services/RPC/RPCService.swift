import Foundation

class RPCService {
    private let rpcBase: RPCBase
    private let rpcLogin: RPCLogin
    
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
        
    }
    
    func authenticate(username: String, password: String) async throws {
        
        try await rpcLogin.login(username: username, password: password)
        
        
        // Fetch encryption info immediately after login to configure RSA keys
        _ = try await security.getEncryptInfo()
        
    }
    
    func disconnect() async throws {
        
        try await rpcLogin.logout()
        
    }
    
    var isAuthenticated: Bool {
        return rpcLogin.hasActiveSession
    }
    
    var hasActiveSession: Bool {
        return rpcBase.hasActiveSession
    }
}

