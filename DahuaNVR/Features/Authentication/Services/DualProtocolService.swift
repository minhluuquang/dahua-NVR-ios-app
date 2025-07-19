import Foundation

struct AuthenticationResult {
    let httpCGI: AuthResult
    let rpc: AuthResult
    let bothSuccessful: Bool
    
    init(httpCGI: AuthResult, rpc: AuthResult) {
        self.httpCGI = httpCGI
        self.rpc = rpc
        self.bothSuccessful = httpCGI.success && rpc.success
    }
}

struct AuthResult {
    let success: Bool
    let error: Error?
    let protocolName: String
    
    init(success: Bool, error: Error? = nil, protocol: String) {
        self.success = success
        self.error = error
        self.protocolName = `protocol`
    }
}

class DualProtocolService {
    private let cgiService: CameraAPIService
    private let rpcService: RPCService
    private let logger = Logger()
    private var isHTTPCGIAuthenticated = false
    
    init(baseURL: String) {
        self.cgiService = CameraAPIService()
        self.rpcService = RPCService(baseURL: baseURL)
        
        #if DEBUG
        logger.debug("Initialized dual protocol service for \(baseURL)")
        #endif
    }
    
    func authenticate(credentials: NVRCredentials) async -> AuthenticationResult {
        #if DEBUG
        logger.debug("Starting dual protocol authentication")
        #endif
        
        var cgiResult: AuthResult
        var rpcResult: AuthResult
        
        async let cgiAuth: () = authenticateCGI(credentials: credentials)
        async let rpcAuth: () = authenticateRPC(credentials: credentials)
        
        do {
            try await cgiAuth
            cgiResult = AuthResult(success: true, protocol: "HTTP CGI")
            #if DEBUG
            logger.debug("HTTP CGI authentication successful")
            #endif
        } catch {
            cgiResult = AuthResult(success: false, error: error, protocol: "HTTP CGI")
            #if DEBUG
            logger.error("HTTP CGI authentication failed: \(error.localizedDescription)")
            #endif
        }
        
        do {
            try await rpcAuth
            rpcResult = AuthResult(success: true, protocol: "RPC")
            #if DEBUG
            logger.debug("RPC authentication successful")
            #endif
        } catch {
            rpcResult = AuthResult(success: false, error: error, protocol: "RPC")
            #if DEBUG
            logger.error("RPC authentication failed: \(error.localizedDescription)")
            #endif
        }
        
        let result = AuthenticationResult(httpCGI: cgiResult, rpc: rpcResult)
        
        #if DEBUG
        logger.debug("Dual authentication completed - CGI: \(cgiResult.success), RPC: \(rpcResult.success)")
        #endif
        
        return result
    }
    
    private func authenticateCGI(credentials: NVRCredentials) async throws {
        // TECH_DEBT: Temporary workaround for circular dependency issue
        // The CameraAPIService relies on AuthenticationManager.shared.currentCredentials
        // which isn't set until AFTER authentication succeeds, creating a circular dependency.
        // Long-term solution: Refactor CameraAPIService to accept explicit credentials
        // in all methods to eliminate global state dependency.
        // Tracking: Authentication architecture refactor
        
        #if DEBUG
        logger.debug("Creating temporary CGI service for authentication test")
        logger.debug("Using explicit credentials to bypass global state dependency")
        #endif
        
        let tempCGIService = CameraAPIService()
        
        do {
            // Test authentication using the new explicit credential method
            try await tempCGIService.authenticate(with: credentials)
            
            isHTTPCGIAuthenticated = true
            #if DEBUG
            logger.debug("CGI authentication test successful")
            #endif
        } catch {
            isHTTPCGIAuthenticated = false
            #if DEBUG
            logger.error("CGI authentication test failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    private func authenticateRPC(credentials: NVRCredentials) async throws {
        try await rpcService.authenticate(username: credentials.username, password: credentials.password)
    }
    
    func disconnect() async {
        #if DEBUG
        logger.debug("Disconnecting dual protocol service")
        #endif
        
        async let cgiDisconnect: () = disconnectCGI()
        async let rpcDisconnect: () = disconnectRPC()
        
        await cgiDisconnect
        await rpcDisconnect
        
        #if DEBUG
        logger.debug("Dual protocol service disconnected")
        #endif
    }
    
    private func disconnectCGI() async {
        isHTTPCGIAuthenticated = false
        #if DEBUG
        logger.debug("CGI disconnected")
        #endif
    }
    
    private func disconnectRPC() async {
        do {
            try await rpcService.disconnect()
        } catch {
            #if DEBUG
            logger.error("RPC disconnect failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    var httpCGI: CameraAPIService {
        return cgiService
    }
    
    var rpc: RPCService {
        return rpcService
    }
    
    var isFullyAuthenticated: Bool {
        return isHTTPCGIAuthenticated && rpcService.isAuthenticated
    }
    
    var hasAnyCGISession: Bool {
        return isHTTPCGIAuthenticated
    }
    
    var hasAnyRPCSession: Bool {
        return rpcService.isAuthenticated
    }
    
    var authenticationStatus: String {
        let cgiStatus = isHTTPCGIAuthenticated ? "✓" : "✗"
        let rpcStatus = rpcService.isAuthenticated ? "✓" : "✗"
        return "CGI: \(cgiStatus), RPC: \(rpcStatus)"
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[DualProtocolService Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[DualProtocolService Error] \(message)")
        #endif
    }
}