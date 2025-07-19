import Foundation
import CryptoKit

struct AuthParams: Codable {
    let random: String
    let realm: String
    let encryption: String
}

struct LoginResult: Codable {
    let keepAliveInterval: Int?
    let session: Int?
    let rspCode: Int?
}

struct FirstLoginParams: Codable {
    let clientType: String
    let ipAddr: String
    let loginType: String
    let userName: String
    let password: String
    
    init(username: String, password: String, clientIP: String = "192.168.1.100") {
        self.clientType = "iPhone"
        self.ipAddr = clientIP
        self.loginType = "Direct"
        self.userName = username
        self.password = password
    }
}

struct SecondLoginParams: Codable {
    let userName: String
    let password: String
    let clientType: String
    let ipAddr: String
    let loginType: String
    
    init(username: String, hashedPassword: String, clientIP: String = "192.168.1.100") {
        self.userName = username
        self.password = hashedPassword
        self.clientType = "iPhone"
        self.ipAddr = clientIP
        self.loginType = "Direct"
    }
}

class RPCLogin {
    private let rpcBase: RPCBase
    private let logger = Logger()
    private var keepAliveTimer: Timer?
    private var keepAliveInterval: Int = 60
    
    init(rpcBase: RPCBase) {
        self.rpcBase = rpcBase
    }
    
    deinit {
        stopKeepAlive()
    }
    
    func login(username: String, password: String) async throws {
        #if DEBUG
        logger.debug("🔐 RPC Authentication Started")
        logger.debug("   → Username: \(username)")
        logger.debug("   → Stage: Two-stage authentication process")
        #endif
        
        try await rpcBase.setupSession()
        
        let authParams = try await firstLogin(username: username, password: password)
        
        #if DEBUG
        logger.debug("✅ RPC First Login Complete")
        logger.debug("   → Received: random=\(authParams.random.prefix(8))..., realm=\(authParams.realm)")
        logger.debug("   → Next: Second login with hashed credentials")
        #endif
        
        try await secondLogin(username: username, password: password, authParams: authParams)
        
        #if DEBUG
        logger.debug("🎉 RPC Authentication Complete")
        logger.debug("   → Status: Successfully authenticated")
        logger.debug("   → Keep-alive: Started (\(keepAliveInterval)s intervals)")
        #endif
        
        startKeepAlive()
    }
    
    func logout() async throws {
        #if DEBUG
        logger.debug("Logging out from RPC session")
        #endif
        
        stopKeepAlive()
        
        do {
            let _: RPCResponse<EmptyResponse> = try await rpcBase.send(
                method: "global.logout",
                responseType: EmptyResponse.self
            )
            #if DEBUG
            logger.debug("RPC logout successful")
            #endif
        } catch {
            #if DEBUG
            logger.error("RPC logout failed: \(error.localizedDescription)")
            #endif
        }
        
        rpcBase.clearSession()
    }
    
    private func firstLogin(username: String, password: String) async throws -> AuthParams {
        let params = FirstLoginParams(username: username, password: password)
        
        let paramsDict: [String: AnyJSON] = [
            "clientType": AnyJSON(params.clientType),
            "ipAddr": AnyJSON(params.ipAddr),
            "loginType": AnyJSON(params.loginType),
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password)
        ]
        
        let response: RPCResponse<AuthParams> = try await rpcBase.send(
            method: "global.login",
            params: paramsDict,
            responseType: AuthParams.self
        )
        
        guard let authParams = response.result else {
            throw RPCError(code: -1, message: "No auth parameters received from first login")
        }
        
        #if DEBUG
        logger.debug("Received auth params - random: \(authParams.random), realm: \(authParams.realm), encryption: \(authParams.encryption)")
        #endif
        
        return authParams
    }
    
    private func secondLogin(username: String, password: String, authParams: AuthParams) async throws {
        let hashedPassword = generateDigestAuth(username: username, password: password, authParams: authParams)
        
        let params = SecondLoginParams(username: username, hashedPassword: hashedPassword)
        
        let paramsDict: [String: AnyJSON] = [
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password),
            "clientType": AnyJSON(params.clientType),
            "ipAddr": AnyJSON(params.ipAddr),
            "loginType": AnyJSON(params.loginType)
        ]
        
        let response: RPCResponse<LoginResult> = try await rpcBase.send(
            method: "global.login",
            params: paramsDict,
            responseType: LoginResult.self
        )
        
        guard let result = response.result else {
            throw RPCError(code: -1, message: "No result received from second login")
        }
        
        if let keepAlive = result.keepAliveInterval {
            keepAliveInterval = keepAlive
            #if DEBUG
            logger.debug("Keep alive interval set to: \(keepAlive) seconds")
            #endif
        }
        
        if let rspCode = result.rspCode, rspCode != 200 {
            throw RPCError(code: rspCode, message: "Authentication failed with response code: \(rspCode)")
        }
        
        #if DEBUG
        logger.debug("Second login successful")
        #endif
    }
    
    private func generateDigestAuth(username: String, password: String, authParams: AuthParams) -> String {
        let passwordHash = md5Hash(password)
        let combinedString = "\(username):\(authParams.realm):\(passwordHash)"
        let combinedHash = md5Hash(combinedString)
        let finalString = "\(combinedHash):\(authParams.random)"
        let finalHash = md5Hash(finalString)
        
        #if DEBUG
        logger.debug("Generated digest auth hash")
        #endif
        
        return finalHash
    }
    
    private func md5Hash(_ string: String) -> String {
        let inputData = Data(string.utf8)
        let hashed = Insecure.MD5.hash(data: inputData)
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
    
    private func startKeepAlive() {
        stopKeepAlive()
        
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(keepAliveInterval), repeats: true) { [weak self] _ in
            Task {
                await self?.sendKeepAlive()
            }
        }
        
        #if DEBUG
        logger.debug("Started keep alive timer with interval: \(keepAliveInterval) seconds")
        #endif
    }
    
    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
        
        #if DEBUG
        logger.debug("Stopped keep alive timer")
        #endif
    }
    
    private func sendKeepAlive() async {
        do {
            let _: RPCResponse<EmptyResponse> = try await rpcBase.send(
                method: "global.keepAlive",
                responseType: EmptyResponse.self
            )
            #if DEBUG
            logger.debug("Keep alive sent successfully")
            #endif
        } catch {
            #if DEBUG
            logger.error("Keep alive failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    var hasActiveSession: Bool {
        return rpcBase.hasActiveSession && keepAliveTimer != nil
    }
}

private struct Logger {
    func debug(_ message: String) {
        #if DEBUG
        print("[RPCLogin Debug] \(message)")
        #endif
    }
    
    func error(_ message: String) {
        #if DEBUG
        print("[RPCLogin Error] \(message)")
        #endif
    }
}