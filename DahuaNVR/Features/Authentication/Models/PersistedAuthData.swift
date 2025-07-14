import Foundation

struct PersistedAuthData: Codable {
    let credentials: NVRCredentials
    let authenticatedAt: Date
    let sessionData: SessionData?
    
    struct SessionData: Codable {
        let realm: String
        let nonce: String
        let qop: String?
        let algorithm: String?
        let opaque: String?
        private let createdAt: Date
        
        var isValid: Bool {
            Date().timeIntervalSince(createdAt) < 3600
        }
        
        init(realm: String, nonce: String, qop: String? = nil, algorithm: String? = nil, opaque: String? = nil) {
            self.realm = realm
            self.nonce = nonce
            self.qop = qop
            self.algorithm = algorithm
            self.opaque = opaque
            self.createdAt = Date()
        }
    }
    
    var isExpired: Bool {
        let timeInterval = Date().timeIntervalSince(authenticatedAt)
        return timeInterval > 86400
    }
    
    init(credentials: NVRCredentials, sessionData: SessionData? = nil) {
        self.credentials = credentials
        self.authenticatedAt = Date()
        self.sessionData = sessionData
    }
}