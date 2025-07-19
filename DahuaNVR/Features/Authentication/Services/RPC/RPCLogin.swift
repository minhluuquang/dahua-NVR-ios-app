import Foundation
import CryptoKit

struct AuthParams: Codable {
    let random: String
    let realm: String
    let encryption: String
    let authorization: String?
    
    init(random: String, realm: String, encryption: String, authorization: String? = nil) {
        self.random = random
        self.realm = realm
        self.encryption = encryption
        self.authorization = authorization
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.random = try container.decode(String.self, forKey: .random)
        self.realm = try container.decode(String.self, forKey: .realm)
        self.encryption = try container.decode(String.self, forKey: .encryption)
        self.authorization = try container.decodeIfPresent(String.self, forKey: .authorization)
    }
    
    private enum CodingKeys: String, CodingKey {
        case random, realm, encryption, authorization
    }
}

struct LoginResult: Codable {
    let keepAliveInterval: Int?
    let session: Int?
    let rspCode: Int?
}

struct FirstLoginParams: Codable {
    let clientType: String
    let ipAddr: String?
    let loginType: String
    let userName: String
    let password: String
    
    init(username: String, password: String = "", clientIP: String? = nil) {
        self.clientType = "Web3.0"  // Match reference implementation
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
    let ipAddr: String?
    let loginType: String
    let authorityType: String?
    
    init(username: String, hashedPassword: String, clientIP: String? = nil, authorityType: String? = nil) {
        self.userName = username
        self.password = hashedPassword
        self.clientType = "Web3.0"  // Match reference implementation
        self.ipAddr = clientIP
        self.loginType = "Direct"
        self.authorityType = authorityType
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
        logger.debug("   → Username: \(username.isEmpty ? "empty" : username)")
        logger.debug("   → Password length: \(password.count) characters")
        logger.debug("   → Password preview: \(password.prefix(3))...")
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
                responseType: EmptyResponse.self,
                useLoginEndpoint: false  // Use regular /RPC2 endpoint for logout (matches reference)
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
        let params = FirstLoginParams(username: username)
        
        var paramsDict: [String: AnyJSON] = [
            "clientType": AnyJSON(params.clientType),
            "loginType": AnyJSON(params.loginType),
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password)
        ]
        
        // Only include ipAddr if it's provided
        if let ipAddr = params.ipAddr {
            paramsDict["ipAddr"] = AnyJSON(ipAddr)
        }
        
        // Use AnyJSON as the response type to handle the flexible JSON structure
        let response: RPCResponse<AnyJSON> = try await rpcBase.send(
            method: "global.login",
            params: paramsDict,
            responseType: AnyJSON.self,
            useLoginEndpoint: true
        )
        
        // Capture session ID from first login response if present
        if let sessionID = response.session {
            rpcBase.setSession(id: sessionID, username: username)
            #if DEBUG
            logger.debug("Session ID captured and set: \(sessionID)")
            #endif
        } else {
            throw RPCError(code: -1, message: "Session ID missing from first login response")
        }
        
        // For challenge responses, the auth parameters are in the params field
        // This is the expected path for first login (challenge response)
        guard let paramsJSON = response.params,
              let paramsDict = paramsJSON.dictionary else {
            throw RPCError(code: -1, message: "No auth parameters received from first login")
        }
        
        // Parse auth parameters using type-safe decoding
        let authParams: AuthParams
        do {
            let paramsData = try JSONSerialization.data(withJSONObject: paramsDict)
            authParams = try JSONDecoder().decode(AuthParams.self, from: paramsData)
        } catch {
            throw RPCError(code: -1, message: "Invalid auth parameters format: \(error.localizedDescription)")
        }
        
        #if DEBUG
        logger.debug("✅ Received login challenge (expected)")
        logger.debug("   → Challenge params: random=\(authParams.random), realm=\(authParams.realm), encryption=\(authParams.encryption)")
        #endif
        
        return authParams
    }
    
    private func secondLogin(username: String, password: String, authParams: AuthParams) async throws {
        let hashedPassword = generateDigestAuth(username: username, password: password, authParams: authParams)
        
        let params = SecondLoginParams(
            username: username, 
            hashedPassword: hashedPassword,
            authorityType: authParams.encryption
        )
        
        var paramsDict: [String: AnyJSON] = [
            "userName": AnyJSON(params.userName),
            "password": AnyJSON(params.password),
            "clientType": AnyJSON(params.clientType),
            "loginType": AnyJSON(params.loginType)
        ]
        
        // Only include optional fields if they're provided
        if let ipAddr = params.ipAddr {
            paramsDict["ipAddr"] = AnyJSON(ipAddr)
        }
        if let authorityType = params.authorityType {
            paramsDict["authorityType"] = AnyJSON(authorityType)
        }
        
        do {
            let response: RPCResponse<LoginResult> = try await rpcBase.send(
                method: "global.login",
                params: paramsDict,
                responseType: LoginResult.self,
                useLoginEndpoint: true  // Use /RPC2_Login endpoint to match reference implementation
            )
            
            guard let result = response.result else {
                if let error = response.error {
                    throw error
                }
                throw RPCError(code: -1, message: "No result received from second login - authentication may have failed")
            }
            
            // Process successful login result
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
            
        } catch let rpcError as RPCError {
            #if DEBUG
            logger.error("❌ Second login failed: \(rpcError.message)")
            #endif
            throw RPCError(code: rpcError.code, message: "Second login authentication failed: \(rpcError.message)")
        }
    }
    
    private func generateDigestAuth(username: String, password: String, authParams: AuthParams) -> String {
        switch authParams.encryption {
        case "Basic":
            // Basic auth: base64(username:password)
            let credentials = "\(username):\(password)"
            return Data(credentials.utf8).base64EncodedString()
            
        case "Default":
            // Default auth: MD5(username:random:MD5(username:realm:password))
            // This is the standard Dahua RPC authentication format
            let realmHash = md5Hash("\(username):\(authParams.realm):\(password)")
            let finalHash = md5Hash("\(username):\(authParams.random):\(realmHash)")
            
            #if DEBUG
            logger.debug("Generated digest auth hash (Default encryption)")
            logger.debug("   → Step 1 input: \(username):\(authParams.realm):\(password)")
            logger.debug("   → Step 1 hash: \(realmHash)")
            logger.debug("   → Step 2 input: \(username):\(authParams.random):\(realmHash)")
            logger.debug("   → Step 2 hash: \(finalHash)")
            logger.debug("   → Algorithm: MD5(username:random:MD5(username:realm:password))")
            #endif
            
            return finalHash
            
        default:
            // Unknown encryption type, return password as-is
            #if DEBUG
            logger.debug("Unknown encryption type: \(authParams.encryption), using password as-is")
            #endif
            return password
        }
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
            let params: [String: AnyJSON] = [
                "timeout": AnyJSON(300),
                "active": AnyJSON(true)
            ]
            
            let _: RPCResponse<[String: Int]> = try await rpcBase.send(
                method: "global.keepAlive",
                params: params,
                responseType: [String: Int].self
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