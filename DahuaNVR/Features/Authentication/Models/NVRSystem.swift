import Foundation

struct NVRSystem: Codable, Identifiable {
    let id: UUID
    let name: String
    let credentials: NVRCredentials
    let isDefault: Bool
    var rpcAuthSuccess: Bool
    var httpCGIAuthSuccess: Bool
    
    init(id: UUID = UUID(), name: String, credentials: NVRCredentials, isDefault: Bool = false, rpcAuthSuccess: Bool = false, httpCGIAuthSuccess: Bool = false) {
        self.id = id
        self.name = name
        self.credentials = credentials
        self.isDefault = isDefault
        self.rpcAuthSuccess = rpcAuthSuccess
        self.httpCGIAuthSuccess = httpCGIAuthSuccess
    }
    
    var isValid: Bool {
        !name.isEmpty && credentials.isValid
    }
    
    var dualAuthAvailable: Bool {
        rpcAuthSuccess && httpCGIAuthSuccess
    }
    
    var authenticationStatus: String {
        let cgiStatus = httpCGIAuthSuccess ? "✓" : "✗"
        let rpcStatus = rpcAuthSuccess ? "✓" : "✗"
        return "CGI: \(cgiStatus), RPC: \(rpcStatus)"
    }
}