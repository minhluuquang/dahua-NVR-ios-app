import Foundation

struct NVRSystem: Codable, Identifiable {
    let id: UUID
    let name: String
    let credentials: NVRCredentials
    let isDefault: Bool
    var rpcAuthSuccess: Bool
    
    init(id: UUID = UUID(), name: String, credentials: NVRCredentials, isDefault: Bool = false, rpcAuthSuccess: Bool = false) {
        self.id = id
        self.name = name
        self.credentials = credentials
        self.isDefault = isDefault
        self.rpcAuthSuccess = rpcAuthSuccess
    }
    
    var isValid: Bool {
        !name.isEmpty && credentials.isValid
    }
    
    var isAuthenticated: Bool {
        rpcAuthSuccess
    }
    
    var authenticationStatus: String {
        let rpcStatus = rpcAuthSuccess ? "✓" : "✗"
        return "RPC: \(rpcStatus)"
    }
}